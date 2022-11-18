targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

@description('The organization DevCenter id')
param OrganizationDevCenterId string

@description('The project defintion to process')
param ProjectDefinition object

// ============================================================================================

var OrganizationDevCenterIdSegments = split(OrganizationDevCenterId, '/')
var Environments = contains(ProjectDefinition, 'environments') ? ProjectDefinition.environments : []
var DevBoxes = contains(OrganizationDefinition, 'devboxes') ? OrganizationDefinition.devboxes : []
var ProjectAdmins = contains(ProjectDefinition, 'admins') ? ProjectDefinition.admins : []
var ProjectUsers = contains(ProjectDefinition, 'users') ? ProjectDefinition.users : []

// ============================================================================================

resource project 'Microsoft.DevCenter/projects@2022-10-12-preview' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
  properties: {
    devCenterId: OrganizationDevCenterId
  }
}

resource projectAdminRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: '331c37c6-af14-46d9-b9f4-e1909e1b95a0'
}

resource projectAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for PrincipalId in ProjectAdmins: if (!empty(PrincipalId)) {
  name: guid(project.id, projectAdminRoleDefinition.id, PrincipalId)
  scope: project
  properties: {
    roleDefinitionId: projectAdminRoleDefinition.id
    principalId: PrincipalId
  }
}] 

resource devBoxUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: '45d50f46-0b78-4001-a660-4198cbe8cd05'
}

resource devBoxUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for PrincipalId in ProjectUsers: if (!empty(PrincipalId)) {
  name: guid(project.id, devBoxUserRoleDefinition.id, PrincipalId)
  scope: project
  properties: {
    roleDefinitionId: devBoxUserRoleDefinition.id
    principalId: PrincipalId
  }
}] 

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        ProjectDefinition.ipRange
      ]
    }
    subnets: [
      {
        name: '${ProjectDefinition.name}Subnet'
        properties: {
          addressPrefix: ProjectDefinition.ipRange
        }
      }
    ]
  }
}

resource networkConnection 'Microsoft.DevCenter/networkConnections@2022-10-12-preview' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
  properties: {
    domainJoinType: 'AzureADJoin'
    subnetId: virtualNetwork.properties.subnets[0].id
    networkingResourceGroupName: '${resourceGroup().name}-NI'
  }
}

module attachNetworkConnection 'attachNetworkConnection.bicep' = {
  name:'${take(deployment().name, 36)}_${uniqueString('attachNetworkConnection', networkConnection.id)}'
  scope: resourceGroup(OrganizationDevCenterIdSegments[2], OrganizationDevCenterIdSegments[4])
  params: {
    DevCenterName: last(OrganizationDevCenterIdSegments)
    NetworkConnectionId: networkConnection.id
  }
}

resource devBoxPool 'Microsoft.DevCenter/projects/pools@2022-10-12-preview' = [for DevBox in DevBoxes: {
  name: '${DevBox.name}Pool'
  location: OrganizationDefinition.Location
  parent: project
  dependsOn: [
    attachNetworkConnection
  ]
  properties: {
    devBoxDefinitionName: DevBox.name
    networkConnectionName: networkConnection.name
    licenseType: 'Windows_Client'
    localAdministrator: 'Enabled'
  }
}]

resource deploymentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = [for Environment in Environments: {
  name: 'Deploy-${Environment.name}'
  location: OrganizationDefinition.location
}]

resource deploymentEnvironment 'Microsoft.DevCenter/projects/environmentTypes@2022-10-12-preview' = [for (Environment, EnvironmentIndex) in Environments: {
  name: Environment.name
  parent: project
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentIdentity[EnvironmentIndex].id}': {}
    }
  }
  tags: {
    IPRange: '192.168.${EnvironmentIndex}.0/24'
  }
  properties: {
    #disable-next-line use-resource-id-functions
    deploymentTargetId: '/subscriptions/${Environment.subscription}'
    status: 'Enabled'
  }
}]

// ============================================================================================

output ProjectSettings object = {
  networkId: virtualNetwork.id
  networkConnectionId: networkConnection.id
}
output EnvironmentSettings array = [for i in range(0, length(Environments)): {
  environmentName: Environments[i].name
  environmentResourceId: deploymentEnvironment[i] .id
  identityResourceId:  deploymentIdentity[i].id
  identityPrincipalId: deploymentIdentity[i].properties.principalId
  ipRange: deploymentEnvironment[i].tags.IPRange
}]
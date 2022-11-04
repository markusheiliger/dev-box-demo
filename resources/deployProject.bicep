targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationJson object

@description('The organization DevCenter id')
param OrganizationDevCenterId string

@description('The project defintion to process')
param ProjectJson object

// ============================================================================================

var Environments = contains(OrganizationJson, 'environments') ? OrganizationJson.environments : []
var ProjectAdmins = contains(ProjectJson, 'admins') ? ProjectJson.admins : []
var ProjectUsers = contains(ProjectJson, 'users') ? ProjectJson.users : []

// ============================================================================================

resource project 'Microsoft.DevCenter/projects@2022-08-01-preview' = {
  name: ProjectJson.name
  location: OrganizationJson.location
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
  name: ProjectJson.name
  location: OrganizationJson.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        ProjectJson.ipRange
      ]
    }
    subnets: [
      {
        name: '${ProjectJson.name}Subnet'
        properties: {
          addressPrefix: ProjectJson.ipRange
        }
      }
    ]
  }
}

resource networkConnection 'Microsoft.DevCenter/networkConnections@2022-08-01-preview' = {
  name: ProjectJson.name
  location: OrganizationJson.location
  properties: {
    domainJoinType: 'AzureADJoin'
    subnetId: virtualNetwork.properties.subnets[0].id
    networkingResourceGroupName: '${resourceGroup().name}-NI'
  }
}

resource deploymentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = [for Environment in Environments: {
  name: Environment
  location: OrganizationJson.location
}]

resource deploymentEnvironment 'Microsoft.DevCenter/projects/environmentTypes@2022-09-01-preview' = [for (Environment, EnvironmentIndex) in Environments: {
  name: Environment
  parent: project
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentIdentity[EnvironmentIndex].id}': {}
    }
  }
  properties: {
    #disable-next-line use-resource-id-functions
    deploymentTargetId: subscription().id
    status: 'Enabled'
  }
}]

// ============================================================================================

output ProjectNetworkId string = virtualNetwork.id
output ProjectNetworkConnectionId string = networkConnection.id

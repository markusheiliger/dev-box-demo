targetScope = 'resourceGroup'

// ============================================================================================

param OrganizationDefinition object
param ProjectDefinition object
param DevCenterId string

// ============================================================================================

var DevBoxes = contains(OrganizationDefinition, 'devboxes') ? OrganizationDefinition.devboxes : []

var ProjectAdmins = contains(ProjectDefinition, 'admins') ? ProjectDefinition.admins : []
var ProjectUsers = contains(ProjectDefinition, 'users') ? ProjectDefinition.users : []

var ProjectSettings = contains(ProjectDefinition, 'settings') ? ProjectDefinition.settings : {}
var ProjectSecrets = contains(ProjectDefinition, 'secrets') ? ProjectDefinition.secrets : {}

// ============================================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: ProjectDefinition.name
}

resource snet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: 'default'
  parent: vnet
}

resource project 'Microsoft.DevCenter/projects@2022-11-11-preview' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
  properties: {
    devCenterId: DevCenterId
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

resource deploymentEnvironmentUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: '18e40d4e-8d2e-438d-97e1-9528336e149c'
}

resource deploymentEnvironmentUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for PrincipalId in ProjectUsers: if (!empty(PrincipalId)) {
  name: guid(project.id, deploymentEnvironmentUserRoleDefinition.id, PrincipalId)
  scope: project
  properties: {
    roleDefinitionId: deploymentEnvironmentUserRoleDefinition.id
    principalId: PrincipalId
  }
}] 

resource networkConnection 'Microsoft.DevCenter/networkConnections@2022-11-11-preview' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
  properties: {
    domainJoinType: 'AzureADJoin'
    subnetId: snet.id
    networkingResourceGroupName: '${resourceGroup().name}-NI'
  }
}

module attachNetworkConnection '../utils/attachNetworkConnection.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString(networkConnection.id)}'
  scope: resourceGroup(split(DevCenterId, '/')[2], split(DevCenterId, '/')[4])
  params: {
    DevCenterName: any(last(split(DevCenterId, '/')))
    NetworkConnectionId: networkConnection.id
  }
}

module attachEnvironment '../utils/attachEnvironment.bicep' = [for EnvironmentDefinition in ProjectDefinition.environments: {
  name: '${take(deployment().name, 36)}_${uniqueString(string(EnvironmentDefinition))}'
  params: {
    ProjectName: project.name
    EnvironmentName: EnvironmentDefinition.name
    EnvironmentSubscription: EnvironmentDefinition.subscription
  }  
}]

resource devBoxPool 'Microsoft.DevCenter/projects/pools@2022-11-11-preview' = [for DevBox in DevBoxes: {
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

resource projectSecrets 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource projectSettings 'Microsoft.AppConfiguration/configurationStores@2022-05-01' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
  sku: {
    name: 'standard'
  }
  identity: {
    type: 'SystemAssigned'   
  }
  properties: {
    // disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

resource vaultSecretUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource vaultSecretUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(projectSecrets.id, vaultSecretUserRoleDefinition.id, projectSettings.id)
  scope: projectSecrets
  properties: {
    principalType: 'ServicePrincipal'
    principalId: projectSettings.identity.principalId
    roleDefinitionId: vaultSecretUserRoleDefinition.id
  }
}

module deploySettings '../utils/deploySettings.bicep' = {
  name: '${take(deployment().name, 36)}_deploySettings'
  scope: resourceGroup()
  params: {
    ConfigurationStoreName: projectSettings.name
    ConfigurationVaultName: projectSecrets.name
    Settings: union(ProjectSettings, {
      ProjectNetworkId: vnet.id
    })
    Secrets: union(ProjectSecrets, {

    })
  }
}
// ============================================================================================

output NetworkConnectionId string = networkConnection.id
output ProjectId string = project.id

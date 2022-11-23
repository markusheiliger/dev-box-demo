targetScope = 'subscription'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

@description('The project defintion to process')
param ProjectDefinition object

@description('The project settings to process')
param ProjectSettings object

@description('The environment defintion to process')
param EnvironmentDefinition object

@description('The environment settings to process')
param EnvironmentSettings object

param DevCenterIdentity string

// ============================================================================================

resource ownerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner
}

resource ownerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, ownerRoleDefinition.id, DevCenterIdentity)
  properties: {
    principalId: DevCenterIdentity
    principalType: 'ServicePrincipal'
    roleDefinitionId: ownerRoleDefinition.id
  }
}

resource environmentResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'Environment-Shared'
  location: OrganizationDefinition.location
}

module deployEnvironment 'deployEnvironment.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString(environmentResourceGroup.id)}'
  scope: environmentResourceGroup
  params: {
    OrganizationDefinition: OrganizationDefinition
    ProjectDefinition: ProjectDefinition
    EnvironmentDefinition: EnvironmentDefinition
    ProjectSettings: ProjectSettings
    EnvironmentSettings: EnvironmentSettings
  }
}

module peerNetworks 'peerNetworks.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('peerNetworks', EnvironmentSettings.environmentName)}'
  scope: subscription()
  params: {
    HubNetworkId: ProjectSettings.networkId
    SpokeNetworkId: deployEnvironment.outputs.EnvironmentNetworkId
  }
}


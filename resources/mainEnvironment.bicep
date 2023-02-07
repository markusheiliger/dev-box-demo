targetScope = 'subscription'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

param OrganizationInfo object

@description('The project defintion to process')
param ProjectDefinition object

param ProjectInfo object

@description('The environment defintion to process')
param EnvironmentDefinition object

param Features object

// ============================================================================================

resource devCenter 'Microsoft.DevCenter/devcenters@2022-10-12-preview' existing = {
  name: any(last(split(OrganizationInfo.DevCenterId, '/')))
  scope: resourceGroup(OrganizationInfo.SubscriptionId, OrganizationInfo.ResourceGroupName)
}

resource ownerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner
}

resource ownerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, ownerRoleDefinition.id, devCenter.id)
  properties: {
    principalId: devCenter.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: ownerRoleDefinition.id
  }
}

resource environmentResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'ENV-${OrganizationDefinition.name}-${ProjectDefinition.name}-${EnvironmentDefinition.name}'
  location: OrganizationDefinition.location
}

module testResourceExists 'utils/testResourceExists.bicep' = {
  name: '${take(deployment().name, 36)}_existsVirtualNetwork'
  scope: environmentResourceGroup
  params: {
    ResourceName: '${ProjectDefinition.name}-${EnvironmentDefinition.name}'
    ResourceType: 'Microsoft.Network/virtualNetworks'
  }
}

module deployResources 'environment/deployResources.bicep' = {
  name: '${take(deployment().name, 36)}_deployResources'
  scope: environmentResourceGroup
  params: {
    EnvironmentDefinition: EnvironmentDefinition
    OrganizationDefinition: OrganizationDefinition
    OrganizationInfo: OrganizationInfo
    ProjectDefinition: ProjectDefinition
    ProjectInfo: ProjectInfo
    InitialDeployment: !testResourceExists.outputs.ResourceExists
  }
}

module attachEnvironment 'utils/attachEnvironment.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('attachEnvironment', EnvironmentDefinition.name)}'
  scope: resourceGroup(ProjectInfo.SubscriptionId, ProjectInfo.ResourceGroupName)
  params:{
    ProjectName: ProjectDefinition.name
    EnvironmentName: EnvironmentDefinition.name
    EnvironmentSubscription: subscription().id
  }
}

module deployTestHost 'utils/deployTestHost.bicep' = if (Features.TestHost) {
  name: '${take(deployment().name, 36)}_deployTestHost'
  scope: environmentResourceGroup
  params: {
    SNetName: deployResources.outputs.DefaultSNetName
    VNetName: deployResources.outputs.VNetName
  }
}

// ============================================================================================

output VNetId string = deployResources.outputs.VNetId
output VNetName string = deployResources.outputs.VNetName
output DefaultSNetId string = deployResources.outputs.DefaultSNetId
output DefaultSNetName string = deployResources.outputs.DefaultSNetName
output IpRanges array = deployResources.outputs.IpRanges


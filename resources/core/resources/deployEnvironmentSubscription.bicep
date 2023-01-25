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

resource environmentResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'ENV-${OrganizationDefinition.name}-${ProjectDefinition.name}-${EnvironmentDefinition.name}'
  location: OrganizationDefinition.location
}

module deployEnvironmentResources 'deployEnvironmentResources.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployEnvironmentResources', EnvironmentDefinition.name)}'
  scope: environmentResourceGroup
  params: {
    EnvironmentDefinition: EnvironmentDefinition
    OrganizationDefinition: OrganizationDefinition
    OrganizationInfo: OrganizationInfo
    ProjectDefinition: ProjectDefinition
    ProjectInfo: ProjectInfo
  }
}

module deployEnvironmentTestHost '../../utils/deployTestHost.bicep' = if (Features.TestHost) {
  name: '${take(deployment().name, 36)}_${uniqueString('deployEnvironmentTestHost', EnvironmentDefinition.name)}'
  scope: environmentResourceGroup
  params: {
    SubNetId: deployEnvironmentResources.outputs.DefaultSNetId
  }
}

// ============================================================================================

output VNetId string = deployEnvironmentResources.outputs.VNetId
output VNetName string = deployEnvironmentResources.outputs.VNetName
output DefaultSNetId string = deployEnvironmentResources.outputs.DefaultSNetId
output DefaultSNetName string = deployEnvironmentResources.outputs.DefaultSNetName
output IpRanges array = deployEnvironmentResources.outputs.IpRanges

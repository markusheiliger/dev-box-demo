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

module deployCoreEnvironmentResources 'deployCore-EnvironmentResources.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployCoreEnvironmentResources', EnvironmentDefinition.name)}'
  scope: environmentResourceGroup
  params: {
    EnvironmentDefinition: EnvironmentDefinition
    OrganizationDefinition: OrganizationDefinition
    ProjectDefinition: ProjectDefinition
  }
}

// module linkEnvironmentZoneToProject '../utils/linkDnsZone.bicep' = {
//   name: '${take(deployment().name, 36)}_${uniqueString('linkEnvironmentZoneToProject')}'
//   scope: environmentResourceGroup
//   params: {
//     PrivateDnsZone: last(split(deployCoreEnvironmentResources.outputs.DnsZoneId, '/'))
//     LinkNetworkIds: [ ProjectInfo.networkId ]
//   }
// }

module deployEnvironmentTestHost '../utils/deployTestHost.bicep' = if (Features.TestHost) {
  name: '${take(deployment().name, 36)}_${uniqueString('deployEnvironmentTestHost', EnvironmentDefinition.name)}'
  scope: environmentResourceGroup
  params: {
    SubNetId: deployCoreEnvironmentResources.outputs.DefaultSubNetId
  }
}

// ============================================================================================

output NetworkId string = deployCoreEnvironmentResources.outputs.NetworkId
output DefaultSubNetId string = deployCoreEnvironmentResources.outputs.DefaultSubNetId
output IpRanges array = deployCoreEnvironmentResources.outputs.IpRanges

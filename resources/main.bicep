targetScope = 'subscription'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

@description('The project defintion to process')
param ProjectDefinition object

@description('The Windows 365 principal id')
param Windows365PrinicalId string

// ============================================================================================

var Features = {
  TestHost: true
} 

var OrganizationInfo = {
  NetworkId: deployCoreOrganizationResources.outputs.NetworkId
  DefaultSubNetId: deployCoreOrganizationResources.outputs.DefaultSubNetId
  DnsZoneId: deployCoreOrganizationResources.outputs.DnsZoneId
}

var ProjectInfo = {
  NetworkId: deployCoreProjectResources.outputs.NetworkId
  DefaultSubNetId: deployCoreProjectResources.outputs.DefaultSubNetId
  DnsZoneId: deployCoreProjectResources.outputs.DnsZoneId
}

// ============================================================================================

resource organizationResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'ORG-${OrganizationDefinition.name}'
  location: OrganizationDefinition.location
}

module deployCoreOrganizationResources 'core/deployCore-OrganizationResources.bicep' ={
  name: '${take(deployment().name, 36)}_${uniqueString('deployCoreOrganizationResources')}'
  scope: organizationResourceGroup
  params: {
    OrganizationDefinition: OrganizationDefinition
    ProjectDefinition: ProjectDefinition
  }
}

resource projectResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'PRJ-${ProjectDefinition.name}'
  location: OrganizationDefinition.location
}

module deployCoreProjectResources 'core/deployCore-ProjectResources.bicep' ={
  name: '${take(deployment().name, 36)}_${uniqueString('deployCoreProjectResources')}'
  scope: projectResourceGroup
  params: {
    OrganizationDefinition: OrganizationDefinition
    ProjectDefinition: ProjectDefinition
  }
}

module environments 'environments.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('environments')}'
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationInfo: OrganizationInfo
    ProjectDefinition: ProjectDefinition
    ProjectInfo: ProjectInfo
    Features: Features
  }
}

resource privateLinkZonesResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: '${organizationResourceGroup.name}-PL'
  location: OrganizationDefinition.location
}

module deployCorePrivateLinkZones 'core/deployCore-PrivateLinkZones.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployCorePrivateLinkZones')}'
  scope: privateLinkZonesResourceGroup
  params: {
    NetworkId: deployCoreOrganizationResources.outputs.NetworkId
    PrivateDnsZones: [
      'privatelink.blob.${az.environment().suffixes.storage}'
    ]
  }
}

module peerOrganizationToProject 'utils/peerNetworks.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('peerOrganizationToProject')}'
  params: {
    HubNetworkId: deployCoreOrganizationResources.outputs.NetworkId
    SpokeNetworkIds: [ deployCoreProjectResources.outputs.NetworkId ]
  }
}

module peerProjectToEnvironments 'utils/peerNetworks.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('peerProjectToEnvironments')}'
  params: {
    HubNetworkId: deployCoreProjectResources.outputs.NetworkId
    SpokeNetworkIds: environments.outputs.NetworkIds
  }
}

module deployOrganizationGateway 'core/deployCore-Gateway.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployOrganizationGateway')}'
  scope: organizationResourceGroup
  dependsOn: [
    peerOrganizationToProject
    peerProjectToEnvironments
  ]
  params: {
    OrganizationDefinition: OrganizationDefinition
    ProjectDefinition: ProjectDefinition
    SubNetId: deployCoreOrganizationResources.outputs.DefaultSubNetId
  }
}

module deployOrganizationTestHost 'utils/deployTestHost.bicep' = if (Features.TestHost) {
  name: '${take(deployment().name, 36)}_${uniqueString('deployOrganizationTestHost')}'
  scope: organizationResourceGroup
  dependsOn: [
    deployOrganizationGateway
  ]
  params: {
    SubNetId: deployCoreOrganizationResources.outputs.DefaultSubNetId
  }
}

module deployProjectGateway 'core/deployCore-Gateway.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployProjectGateway')}'
  scope: projectResourceGroup
  dependsOn: [
    peerOrganizationToProject
    peerProjectToEnvironments
  ]
  params: {
    OrganizationDefinition: OrganizationDefinition
    ProjectDefinition: ProjectDefinition
    SubNetId: deployCoreProjectResources.outputs.DefaultSubNetId
    DnsForwards: [ deployOrganizationGateway.outputs.GatewayIp ]
    NetBlocks: deployCoreOrganizationResources.outputs.IpRanges
    NetForwards: flatten(map(environments.outputs.EnvironmentInfos, item => item.IpRanges))
  }
}

module deployProjectTestHost 'utils/deployTestHost.bicep' = if (Features.TestHost) {
  name: '${take(deployment().name, 36)}_${uniqueString('deployProjectTestHost')}'
  scope: projectResourceGroup
  dependsOn: [
    deployProjectGateway
  ]
  params: {
    SubNetId: deployCoreProjectResources.outputs.DefaultSubNetId
  }
}


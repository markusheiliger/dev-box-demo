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
  NetworkId: deployOrganizationResources.outputs.VNetId
  DefaultSubNetId: deployOrganizationResources.outputs.DefaultSNetId
  DnsZoneId: deployOrganizationResources.outputs.DnsZoneId
}

var ProjectInfo = {
  NetworkId: deployProjectResources.outputs.VNetId
  DefaultSubNetId: deployProjectResources.outputs.DefaultSNetId
  DnsZoneId: deployProjectResources.outputs.DnsZoneId
}

// ============================================================================================

resource organizationResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'ORG-${OrganizationDefinition.name}'
  location: OrganizationDefinition.location
}

module deployOrganizationResources 'core/resources/deployOrganizationResources.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployOrganizationResources')}'
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

module deployProjectResources 'core/resources/deployProjectResources.bicep' ={
  name: '${take(deployment().name, 36)}_${uniqueString('deployProjectResources')}'
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

module deployPrivateLinkZones 'core/resources/deployPrivateLinkZones.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployPrivateLinkZones')}'
  scope: privateLinkZonesResourceGroup
  params: {
    NetworkId: deployOrganizationResources.outputs.VNetId
    PrivateDnsZones: [
      'privatelink.blob.${az.environment().suffixes.storage}'
    ]
  }
}

module peerOrganizationToProject 'utils/peerNetworks.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('peerOrganizationToProject')}'
  params: {
    HubNetworkId: deployOrganizationResources.outputs.VNetId
    SpokeNetworkIds: [ deployProjectResources.outputs.VNetId ]
  }
}

module peerProjectToEnvironments 'utils/peerNetworks.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('peerProjectToEnvironments')}'
  params: {
    HubNetworkId: deployProjectResources.outputs.VNetId
    SpokeNetworkIds: environments.outputs.VNetIds
  }
}

module deployOrganizationGateway 'core/gateway/deployGateway.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployOrganizationGateway')}'
  scope: organizationResourceGroup
  dependsOn: [
    peerOrganizationToProject
    peerProjectToEnvironments
  ]
  params: {
    VNetName: deployOrganizationResources.outputs.VNetName
    SNetName: deployOrganizationResources.outputs.DefaultSNetName
    OrganizationDefinition: OrganizationDefinition
    ProjectDefinition: ProjectDefinition
  }
}

module deployOrganizationTestHost 'utils/deployTestHost.bicep' = if (Features.TestHost) {
  name: '${take(deployment().name, 36)}_${uniqueString('deployOrganizationTestHost')}'
  scope: organizationResourceGroup
  dependsOn: [
    deployOrganizationGateway
  ]
  params: {
    SubNetId: deployOrganizationResources.outputs.DefaultSNetId
  }
}

module deployProjectGateway 'core/gateway/deployGateway.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployProjectGateway')}'
  scope: projectResourceGroup
  dependsOn: [
    peerOrganizationToProject
    peerProjectToEnvironments
  ]
  params: {
    OrganizationDefinition: OrganizationDefinition
    ProjectDefinition: ProjectDefinition
    VNetName: deployProjectResources.outputs.VNetName
    SNetName: deployProjectResources.outputs.DefaultSNetName
    DnsForwards: [ '${deployOrganizationResources.outputs.DnsZoneName}>${deployOrganizationGateway.outputs.GatewayIp}' ]
    NetBlocks: deployOrganizationResources.outputs.IpRanges
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
    SubNetId: deployProjectResources.outputs.DefaultSNetId
  }
}


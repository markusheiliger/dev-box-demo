targetScope = 'subscription'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

@description('The Windows 365 principal id')
param Windows365PrinicalId string

param Features object

// ============================================================================================

resource organizationResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'ORG-${OrganizationDefinition.name}'
  location: OrganizationDefinition.location
}

module existsVirtualNetwork 'utils/existsResource.bicep' = {
  name: '${take(deployment().name, 36)}_existsVirtualNetwork'
  scope: organizationResourceGroup
  params: {
    ResourceName: OrganizationDefinition.name
    ResourceType: 'Microsoft.Network/virtualNetworks'
  }
}

module deployResources './organization/deployResources.bicep' = {
  name: '${take(deployment().name, 36)}_deployResources'
  scope: organizationResourceGroup
  params: {
    OrganizationDefinition: OrganizationDefinition
    InitialDeployment: !existsVirtualNetwork.outputs.ResourceExists
  }
}

module deployGateway './organization/deployGateway.bicep' = {
  name: '${take(deployment().name, 36)}_deployGateway'
  scope: organizationResourceGroup
  dependsOn: [
    deployResources
  ]
  params: {
    OrganizationDefinition: OrganizationDefinition
  }
}

module deployBastion 'organization/deployBastion.bicep' ={
  name: '${take(deployment().name, 36)}_deployBastion'
  scope: organizationResourceGroup
  dependsOn: [
    deployResources
  ]
  params: {
    OrganizationDefinition: OrganizationDefinition
  }
}

module deployDevCloud 'organization/deployDevCloud.bicep' = {
  name: '${take(deployment().name, 36)}_deployDevCloud'
  scope: organizationResourceGroup
  dependsOn: [
    deployResources
  ]
  params: {
    OrganizationDefinition: OrganizationDefinition
    Windows365PrinicalId: Windows365PrinicalId
  }
}

module deployTestHost 'utils/deployTestHost.bicep' = if (Features.TestHost) {
  name: '${take(deployment().name, 36)}_deployTestHost'
  scope: organizationResourceGroup
  dependsOn: [
    deployGateway
  ]
  params: {
    SNetName: deployResources.outputs.DefaultSNetName
    VNetName: deployResources.outputs.VNetName
  }
}

resource privateLinkZonesResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: '${organizationResourceGroup.name}-PL'
  location: OrganizationDefinition.location
}

module deployPrivateLinkZones 'shared/deployPrivateLinkZones.bicep' = {
  name: '${take(deployment().name, 36)}_deployPrivateLinkZones'
  scope: privateLinkZonesResourceGroup
  params: {
    PrivateDnsZones: [
      'privatelink.blob.${az.environment().suffixes.storage}'
    ]
  }
}
// ============================================================================================

output OrganizationInfo object = {
  SubscriptionId: subscription().subscriptionId
  ResourceGroupId: organizationResourceGroup.id
  ResourceGroupName: organizationResourceGroup.name
  NetworkId: deployResources.outputs.VNetId
  DefaultSubNetId: deployResources.outputs.DefaultSNetId
  DnsZoneId: deployResources.outputs.DnsZoneId
  DevCenterId: deployDevCloud.outputs.DevCenterId
  GatewayIP: deployGateway.outputs.GatewayIP
}

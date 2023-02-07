targetScope = 'resourceGroup'

// ============================================================================================

param OrganizationDefinition object

param InitialDeployment bool = true

// ============================================================================================

var DefaultSubnetDefinition = first(filter(OrganizationDefinition.network.subnets, subnet => subnet.name == 'default'))

var SubNetDefinitionsCustom = filter(OrganizationDefinition.network.subnets, net => !startsWith(net.name, 'Azure'))
var SubNetDefinitionsAzure = filter(OrganizationDefinition.network.subnets, net => startsWith(net.name, 'Azure'))

var SubNets = concat(
  map(SubNetDefinitionsCustom, net => {
    name: net.name
    properties: {
      addressPrefix: net.ipRange
      routeTable: { id: routes.id }
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled' 
    }
  }),
  map(SubNetDefinitionsAzure, net => {
    name: net.name
    properties: {
      addressPrefix: net.ipRange
    }
  })
)

// ============================================================================================

resource routes 'Microsoft.Network/routeTables@2022-07-01' = {
  name: OrganizationDefinition.name
  location: OrganizationDefinition.location
}

resource virtualNetworkCreate 'Microsoft.Network/virtualNetworks@2022-07-01' = if (InitialDeployment) {
  name: OrganizationDefinition.name
  location: OrganizationDefinition.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        OrganizationDefinition.network.ipRange  
      ]
    }  
    subnets: SubNets
  }  
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: OrganizationDefinition.name
}

resource defaultSubNet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: DefaultSubnetDefinition.name
  parent: virtualNetwork
}

resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: toLower(OrganizationDefinition.zone)
  location: 'global'
}

resource dnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'VNet-${guid(virtualNetwork.id)}'
  parent: dnsZone
  location: 'global'
  dependsOn: [
    virtualNetworkCreate
  ]
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}


// ============================================================================================

output VNetId string = virtualNetwork.id
output VNetName string = virtualNetwork.name
output DefaultSNetId string = defaultSubNet.id
output DefaultSNetName string = defaultSubNet.name
output DnsZoneId string = dnsZone.id
output DnsZoneName string = dnsZone.name
output IpRanges array = virtualNetwork.properties.addressSpace.addressPrefixes

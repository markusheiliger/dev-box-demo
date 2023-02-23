targetScope = 'resourceGroup'

// ============================================================================================

param OrganizationDefinition object
param OrganizationGatewayIP string
param OrganizationNetworkId string
param ProjectDefinition object
param InitialDeployment bool = false

// ============================================================================================

var DefaultSubnetDefinition = first(filter(ProjectDefinition.network.subnets, subnet => subnet.name == 'default'))

var SubNetRoutes = map(filter(ProjectDefinition.network.subnets, net => !startsWith(net.name, 'Azure')), net => '${ProjectDefinition.name}-RT-${net.name}')

var SubNetConfigs = map(ProjectDefinition.network.subnets, net => !startsWith(net.name, 'Azure') ? {
    name: net.name
    properties: {
      addressPrefix: net.ipRange
      routeTable: { id: resourceId('Microsoft.Network/routeTables', '${ProjectDefinition.name}-RT-${net.name}') }
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled' 
    }
  } : {
    name: net.name
    properties: {
      addressPrefix: net.ipRange
    }
  })

// ============================================================================================

resource routes 'Microsoft.Network/routeTables@2022-07-01' = [for name in SubNetRoutes : {
  name: name
  location: OrganizationDefinition.location
}]

resource virtualNetworkCreate 'Microsoft.Network/virtualNetworks@2022-07-01' = if (InitialDeployment) {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
  dependsOn: [
    routes
  ]
  properties: {
    addressSpace: {
      addressPrefixes: [
        ProjectDefinition.network.ipRange
      ]
    }
    dhcpOptions: {
      dnsServers: [
        '168.63.129.16'
        OrganizationGatewayIP
      ]
    }
    subnets: SubNetConfigs
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: ProjectDefinition.name
}

resource defaultSubNet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: DefaultSubnetDefinition.name
  parent: virtualNetwork
}

resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: toLower('${ProjectDefinition.name}.${OrganizationDefinition.zone}')
  location: 'global'
}

resource dnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${virtualNetwork.name}-${guid(virtualNetwork.id)}'
  parent: dnsZone
  location: 'global'
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource dnsZoneLinkOrganization 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${virtualNetwork.name}-${guid(OrganizationNetworkId)}'
  parent: dnsZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: OrganizationNetworkId
    }
  }
}

// ============================================================================================

output VNetId string = virtualNetwork.id
output VNetName string = virtualNetwork.name
output DefaultSNetId string = defaultSubNet.id
output DefaultSNetName string = defaultSubNet.name
output DnsZoneId string = dnsZone.id
output IpRanges array = virtualNetwork.properties.addressSpace.addressPrefixes

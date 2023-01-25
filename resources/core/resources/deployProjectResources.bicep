targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

@description('The project defintion to process')
param ProjectDefinition object

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        ProjectDefinition.ipRange
      ]
    }
  }
}

resource defaultSubNet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  name: 'default'
  parent: virtualNetwork
  properties: {
    addressPrefix: ProjectDefinition.ipRange
    routeTable: {
        id: routes.id
    }
  }
}

resource routes 'Microsoft.Network/routeTables@2022-07-01' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
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

// ============================================================================================

output VNetId string = virtualNetwork.id
output VNetName string = virtualNetwork.name
output DefaultSNetId string = defaultSubNet.id
output DefaultSNetName string = defaultSubNet.name
output RouteTableId string = routes.id
output RouteTableName string = routes.name
output DnsZoneId string = dnsZone.id
output IpRanges array = virtualNetwork.properties.addressSpace.addressPrefixes

targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

@description('The project defintion to process')
param ProjectDefinition object

// ============================================================================================

var DefaultSubnetDefinition = first(filter(OrganizationDefinition.network.subnets, subnet => subnet.name == 'default'))

var ScriptFiles = [
  {
    name: 'initGateway.sh'
    content: loadFileAsBase64('../scripts/initGateway.sh')
  }
]

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: OrganizationDefinition.name
  location: OrganizationDefinition.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        OrganizationDefinition.network.ipRange  
      ]
    } 
  }
}

resource defaultSubNet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  name: DefaultSubnetDefinition.name
  parent: virtualNetwork
  properties: {
    addressPrefix: DefaultSubnetDefinition.ipRange
    routeTable: {
        id: routes.id
    }
  }
}

resource routes 'Microsoft.Network/routeTables@2022-07-01' = {
  name: OrganizationDefinition.name
  location: OrganizationDefinition.location
}

resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: toLower(OrganizationDefinition.zone)
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

output NetworkId string = virtualNetwork.id
output DefaultSubNetId string = defaultSubNet.id
output DnsZoneId string = dnsZone.id


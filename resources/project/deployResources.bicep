targetScope = 'resourceGroup'

// ============================================================================================

param OrganizationDefinition object

param OrganizationInfo object

param ProjectDefinition object

param InitialDeployment bool = true

// ============================================================================================

resource routes 'Microsoft.Network/routeTables@2022-07-01' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
}

resource defaultRoute 'Microsoft.Network/routeTables/routes@2022-07-01' = {
  name: 'default'
  parent: routes
  properties: {
    nextHopType: 'VirtualAppliance'
    addressPrefix: '0.0.0.0/0'
    nextHopIpAddress: OrganizationInfo.GatewayIP
  }
}

resource virtualNetworkCreate 'Microsoft.Network/virtualNetworks@2022-07-01' = if (InitialDeployment) {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        ProjectDefinition.ipRange
      ]
    }
    dhcpOptions: {
      dnsServers: [
        '168.63.129.16'
        OrganizationInfo.GatewayIP
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: ProjectDefinition.ipRange
          routeTable: {
              id: routes.id
          }
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: ProjectDefinition.name
}

resource defaultSubNet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: 'default'
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

module peerNetworks '../utils/peerNetworks.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('peerNetworks', virtualNetwork.id)}'
  scope: subscription()
  params: {
    HubNetworkId: OrganizationInfo.NetworkId
    SpokeNetworkIds: [ virtualNetwork.id ]
    UpdateHubNetworkIPGroups: true
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

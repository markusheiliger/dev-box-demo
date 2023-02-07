targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

param OrganizationInfo object

@description('The project defintion to process')
param ProjectDefinition object

param ProjectInfo object

@description('The environment defintion to process')
param EnvironmentDefinition object

param InitialDeployment bool = true

// ============================================================================================

var ResourceName = '${ProjectDefinition.name}-${EnvironmentDefinition.name}'

// ============================================================================================

resource routes 'Microsoft.Network/routeTables@2022-07-01' = {
  name: ResourceName
  location: OrganizationDefinition.location
}

resource defaultRoute 'Microsoft.Network/routeTables/routes@2022-07-01' = {
  name: 'default'
  parent: routes
  properties: {
    nextHopType: 'VirtualAppliance'
    addressPrefix: '0.0.0.0/0'
    nextHopIpAddress: ProjectInfo.GatewayIP
  }
}

resource virtualNetworkCreate 'Microsoft.Network/virtualNetworks@2022-07-01' = if (InitialDeployment) {
  name: ResourceName
  location: OrganizationDefinition.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        EnvironmentDefinition.ipRange  
      ]
    } 
    dhcpOptions: {
      dnsServers: [
        '168.63.129.16'
        ProjectInfo.GatewayIP
        OrganizationInfo.GatewayIP
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: EnvironmentDefinition.ipRange
          routeTable: {
              id: routes.id
          }
        }
      }      
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: ResourceName
}

resource defaultSubNet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: 'default'
  parent: virtualNetwork
}

resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: toLower('${EnvironmentDefinition.name}.${ProjectDefinition.name}.${OrganizationDefinition.zone}')
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

resource dnsZoneLinkProject 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: '${virtualNetwork.name}-${guid(ProjectInfo.NetworkId)}'
  parent: dnsZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: ProjectInfo.NetworkId
    }
  }
}

module peerNetworks '../utils/peerNetworks.bicep' = {
  name: '${take(deployment().name, 36)}_peerNetworks'
  scope: subscription()
  params: {
    HubNetworkId: ProjectInfo.NetworkId
    SpokeNetworkIds: [ virtualNetwork.id ]
  }
}

// ============================================================================================

output VNetId string = virtualNetwork.id
output VNetName string = virtualNetwork.name
output DefaultSNetId string = defaultSubNet.id
output DefaultSNetName string = defaultSubNet.name
output DnsZoneId string = dnsZone.id
output IpRanges array = virtualNetwork.properties.addressSpace.addressPrefixes

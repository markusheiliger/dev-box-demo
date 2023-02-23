targetScope = 'resourceGroup'

// ============================================================================================

param OrganizationDefinition object
param ProjectDefinition object
param EnvironmentDefinition object
param InitialDeployment bool = true
param ProjectGatewayIP string
param ProjectNetworkId string

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
    nextHopIpAddress: ProjectGatewayIP
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
        ProjectGatewayIP
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
  name: '${virtualNetwork.name}-${guid(ProjectNetworkId)}'
  parent: dnsZone
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: ProjectNetworkId
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

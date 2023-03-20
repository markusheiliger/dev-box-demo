targetScope = 'resourceGroup'

// ============================================================================================

param OrganizationDefinition object
param InitialDeployment bool = true

// ============================================================================================

resource routes 'Microsoft.Network/routeTables@2022-07-01' = {
  name: OrganizationDefinition.name
  location: OrganizationDefinition.location
}

module splitSubnets '../utils/splitSubnets.bicep' = {
  name: '${take(deployment().name, 36)}_splitSubnets'
  params: {
    IPRange: OrganizationDefinition.ipRange
    SubnetCount: 3
  }
}

resource virtualNetworkCreate 'Microsoft.Network/virtualNetworks@2022-07-01' = if (InitialDeployment) {
  name: OrganizationDefinition.name
  location: OrganizationDefinition.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        OrganizationDefinition.ipRange  
      ]
    }  
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: splitSubnets.outputs.Subnets[0]
          routeTable: { 
            id: routes.id 
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled' 
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: splitSubnets.outputs.Subnets[1]
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: splitSubnets.outputs.Subnets[2]
        }
      }
    ]
  }  
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: OrganizationDefinition.name
}

resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: toLower(OrganizationDefinition.zone)
  location: 'global'
}

resource dnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'VNet-${guid(vnet.id)}'
  parent: dnsZone
  location: 'global'
  dependsOn: [
    virtualNetworkCreate
  ]
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// ============================================================================================

output VNetId string = vnet.id
output VNetName string = vnet.name
output DnsZoneId string = dnsZone.id
output DnsZoneName string = dnsZone.name
output IpRanges array = vnet.properties.addressSpace.addressPrefixes

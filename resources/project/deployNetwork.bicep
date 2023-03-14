targetScope = 'resourceGroup'

// ============================================================================================

param OrganizationDefinition object
param OrganizationGatewayIP string
param OrganizationNetworkId string
param ProjectDefinition object
param InitialDeployment bool = false

// ============================================================================================

resource routes 'Microsoft.Network/routeTables@2022-07-01' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
}

module splitSubnets '../utils/splitSubnets.bicep' = if (InitialDeployment) {
  name: '${take(deployment().name, 36)}_splitSubnets'
  params: {
    IPRange: ProjectDefinition.ipRange
    SubnetCount: 2
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
        OrganizationGatewayIP
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
        }
      }
      {
        name: 'gateway'
        properties: {
          addressPrefix: splitSubnets.outputs.Subnets[1]
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: ProjectDefinition.name
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
      id: InitialDeployment ? virtualNetworkCreate.id : virtualNetwork.id
    }
  }
}

// resource dnsZoneLinkOrganization 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
//   name: '${virtualNetwork.name}-${guid(OrganizationNetworkId)}'
//   parent: dnsZone
//   location: 'global'
//   properties: {
//     registrationEnabled: false
//     virtualNetwork: {
//       id: OrganizationNetworkId
//     }
//   }
// }

// ============================================================================================

output VNetId string = virtualNetwork.id
output VNetName string = virtualNetwork.name
output DnsZoneId string = dnsZone.id
output IpRanges array = virtualNetwork.properties.addressSpace.addressPrefixes

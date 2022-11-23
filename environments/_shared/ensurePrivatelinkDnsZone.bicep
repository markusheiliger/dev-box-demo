targetScope = 'resourceGroup'

// ============================================================================================

param DNSZoneName string

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-05-01' existing = {
  name: 'Environment'
  scope: resourceGroup()
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: DNSZoneName
  location: 'global'
  properties: {}
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${DNSZoneName}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

// ============================================================================================

output DNSZoneId string = privateDnsZone.id

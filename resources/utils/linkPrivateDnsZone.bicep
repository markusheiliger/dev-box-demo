targetScope = 'resourceGroup'

// ============================================================================================

param ZoneName string

param NetworkIds array

// ============================================================================================

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: ZoneName
  location: 'global'
  properties: {}
}

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for id in NetworkIds: {
  parent: privateDnsZone
  name: '${guid(id)}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: id
    }
  }
}]

// ============================================================================================

output ZoneId string = privateDnsZone.id

targetScope = 'resourceGroup'

// ============================================================================================

param PrivateDnsZones array

param NetworkId string

// ============================================================================================

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = [for PrivateDnsZone in PrivateDnsZones: {
  name: PrivateDnsZone
  location: 'global'
}]

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for i in range(0, length(PrivateDnsZones)): {
    name: last(split(NetworkId, '/'))
    parent: privateDnsZone[i]
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: NetworkId
      }
    }
}]




targetScope = 'resourceGroup'

// ============================================================================================

param PrivateLinkDnsZoneName string

param ProjectNetworkId string

param EnvironmentNetworkIds array = []

// ============================================================================================

resource privateLinkDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: PrivateLinkDnsZoneName
  location: 'global'
}

resource privateLinkDnsZoneLink_project 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: last(split(ProjectNetworkId, '/'))
  location: 'global'
  parent: privateLinkDnsZone
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: ProjectNetworkId
    }
  }
}

resource privateLinkDnsZoneLink_environment 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [ for EnvironmentNetworkId in EnvironmentNetworkIds : {
  name: '${last(split(EnvironmentNetworkId, '/'))}-${uniqueString(EnvironmentNetworkId)}'
  location: 'global'
  parent: privateLinkDnsZone
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: EnvironmentNetworkId
    }
  }
}]


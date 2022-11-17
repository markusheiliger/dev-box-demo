targetScope = 'subscription'

// ============================================================================================

@description('The hub network id')
param HubNetworkId string

@description('The hub network gateway id')
param HubGatewayIPAddress string = ''

@description('The spoke network id')
param SpokeNetworkId string

// ============================================================================================

resource hubNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' existing = {
  name: last(split(HubNetworkId, '/'))
  scope: resourceGroup(split(HubNetworkId, '/')[2], split(HubNetworkId, '/')[4])
}

resource spokeNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' existing = {
  name: last(split(SpokeNetworkId, '/'))
  scope: resourceGroup(split(SpokeNetworkId, '/')[2], split(SpokeNetworkId, '/')[4])
}

module peerHub2Spoke 'peerNetwork.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('peerNetwork', SpokeNetworkId)}'
  scope: resourceGroup(split(HubNetworkId, '/')[2], split(HubNetworkId, '/')[4])
  params: {
    LocalVirtualNetworkName: hubNetwork.name
    LocalVirtualNetworkLocation: hubNetwork.location
    RemoteVirtualNetworkId: SpokeNetworkId
  }
}

module peerSpoke2Hub 'peerNetwork.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('peerNetwork', HubNetworkId)}'
  scope: resourceGroup(split(SpokeNetworkId, '/')[2], split(SpokeNetworkId, '/')[4])
  params: {
    LocalVirtualNetworkName: spokeNetwork.name
    LocalVirtualNetworkLocation: spokeNetwork.location
    RemoteVirtualNetworkId: HubNetworkId
    RemoteGatewayIPAddress: HubGatewayIPAddress
  }
}


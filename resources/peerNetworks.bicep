targetScope = 'subscription'

// ============================================================================================

@description('The hub network id')
param HubNetworkId string

@description('The spoke network id')
param SpokeNetworkId string

// ============================================================================================

module peerHub2Spoke 'peerNetwork.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('peerNetwork', SpokeNetworkId)}'
  scope: resourceGroup(split(HubNetworkId, '/')[4])
  params: {
    LocalVirtualNetworkName: last(split(HubNetworkId, '/'))
    RemoteVirtualNetworkId: SpokeNetworkId
  }
}

module peerSpoke2Hub 'peerNetwork.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('peerNetwork', HubNetworkId)}'
  scope: resourceGroup(split(SpokeNetworkId, '/')[4])
  params: {
    LocalVirtualNetworkName: last(split(SpokeNetworkId, '/'))
    RemoteVirtualNetworkId: HubNetworkId
  }
}

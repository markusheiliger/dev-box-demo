targetScope = 'subscription'

// ============================================================================================

param HubNetworkId string

param SpokeNetworkIds array

param OperationId string = newGuid()

// ============================================================================================

resource hubNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: last(split(HubNetworkId, '/'))
  scope: resourceGroup(split(HubNetworkId, '/')[2], split(HubNetworkId, '/')[4])
}

module peerHub2Spoke 'peerNetwork.bicep' = [for i in range(0, length(SpokeNetworkIds)): {
  name: '${take(deployment().name, 36)}_${uniqueString('peerNetwork', SpokeNetworkIds[i], OperationId)}'
  scope: resourceGroup(split(HubNetworkId, '/')[2], split(HubNetworkId, '/')[4])
  params: {
    LocalVirtualNetworkName: hubNetwork.name
    RemoteVirtualNetworkId: SpokeNetworkIds[i]
  }
}]

resource spokeNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = [for SpokeNetworkId in SpokeNetworkIds: {
  name: last(split(SpokeNetworkId, '/'))
  scope: resourceGroup(split(SpokeNetworkId, '/')[2], split(SpokeNetworkId, '/')[4])
}]

module peerSpoke2Hub 'peerNetwork.bicep' = [for i in range(0, length(SpokeNetworkIds)): {
  name: '${take(deployment().name, 36)}_${uniqueString('peerNetwork', HubNetworkId, OperationId)}'
  scope: resourceGroup(split(SpokeNetworkIds[i], '/')[2], split(SpokeNetworkIds[i], '/')[4])
  params: {
    LocalVirtualNetworkName: spokeNetwork[i].name
    RemoteVirtualNetworkId: HubNetworkId
  }
}]

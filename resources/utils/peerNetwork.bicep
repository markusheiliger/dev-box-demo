targetScope = 'resourceGroup'

// ============================================================================================

param LocalVirtualNetworkName string
param RemoteVirtualNetworkId string
param WaitUntilSucceeded bool = false
param OperationId string = newGuid()

// ============================================================================================

resource localVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: LocalVirtualNetworkName
}

module testVirtualNetworkSucceeded 'testResourceState.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('testVirtualNetworkSucceeded', localVirtualNetwork.id, OperationId)}'
  params: {
    ResourceId: localVirtualNetwork.id
    OperationIsolated: true
  }
}

resource peerVirtualNetwork 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-02-01' = {
  name: 'peer-${guid(RemoteVirtualNetworkId)}'
  parent: localVirtualNetwork
  dependsOn: [
    testVirtualNetworkSucceeded
  ]
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false 
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: RemoteVirtualNetworkId
    }
  }
}

module testVirtualNetworkPeeringSucceeded 'testResourceState.bicep' = if (WaitUntilSucceeded) {
  name: '${take(deployment().name, 36)}_${uniqueString('testVirtualNetworkPeeringSucceeded', peerVirtualNetwork.id, OperationId)}'
  params: {
    ResourceId: peerVirtualNetwork.id
  }
}

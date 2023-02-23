targetScope = 'resourceGroup'

// ============================================================================================

param LocalVirtualNetworkName string
param RemoteVirtualNetworkId string
param PeeringPrefix string 

// ============================================================================================

resource localVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: LocalVirtualNetworkName
}

resource peerVirtualNetwork 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-02-01' = {
  name: '${PeeringPrefix}-${guid(localVirtualNetwork.id, RemoteVirtualNetworkId)}'
  parent: localVirtualNetwork
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

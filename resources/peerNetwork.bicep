targetScope = 'resourceGroup'

// ============================================================================================

@description('Set the local VNet name')
param LocalVirtualNetworkName string

@description('Set the remote VNet identifier')
param RemoteVirtualNetworkId string

// ============================================================================================

resource localVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: LocalVirtualNetworkName
}

resource existingLocalVirtualNetworkName_peering_to_remote_vnet 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-02-01' = {
  name: 'peer-${guid(RemoteVirtualNetworkId)}'
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

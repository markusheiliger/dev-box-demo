targetScope = 'resourceGroup'

// ============================================================================================

@description('Set the local VNet name')
param LocalVirtualNetworkName string

@description('Set the local VNet name')
param LocalVirtualNetworkLocation string

@description('Set the remote VNet identifier')
param RemoteVirtualNetworkId string

@description('The IP address of the remote network gateway')
param RemoteGatewayIPAddress string = ''

// ============================================================================================

resource localVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: LocalVirtualNetworkName
}

resource peerVirtualNetwork 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-02-01' = {
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

resource routeNextHopToFirewall 'Microsoft.Network/routeTables@2022-01-01' = if (!empty(RemoteGatewayIPAddress)) {
  name: '${LocalVirtualNetworkName}-RT'
  location: LocalVirtualNetworkLocation
  properties: {
    routes: [
      {
        name: 'nexthop-to-remote-gateway'
        properties: {
          nextHopType: 'VirtualAppliance'
          addressPrefix: '0.0.0.0/0'
          nextHopIpAddress: RemoteGatewayIPAddress
        }
      }
    ]
  }
}

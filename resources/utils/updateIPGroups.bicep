
targetScope = 'resourceGroup'

// ============================================================================================

param VNetName string

// ============================================================================================

#disable-next-line no-loc-expr-outside-params
var ResourceLocation = resourceGroup().location

// ============================================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: VNetName
}

resource ipGroupLocal 'Microsoft.Network/ipGroups@2022-01-01' = {
  name: '${vnet.name}-IPG-LOCAL'
  location: ResourceLocation
  properties: {
    ipAddresses: vnet.properties.addressSpace.addressPrefixes
  }
}

resource ipGroupPeered 'Microsoft.Network/ipGroups@2022-01-01' = {
  name: '${vnet.name}-IPG-PEERED'
  location: ResourceLocation
  dependsOn: [
    ipGroupLocal
  ]
  properties: {
    ipAddresses: flatten(map(vnet.properties.virtualNetworkPeerings, peer => peer.properties.remoteVirtualNetworkAddressSpace.addressPrefixes))
  }
}

// ============================================================================================

output IPGroupLocalName string = ipGroupLocal.name
output IPGroupLocalId string = ipGroupLocal.id

output IPGroupPeeredName string = ipGroupPeered.name
output IPGroupPeeredId string = ipGroupPeered.id

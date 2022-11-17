targetScope = 'resourceGroup'

// ============================================================================================

param VirtualNetworkName string

param SubnetName string

param SubnetProperties object

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-05-01' existing = {
  name: VirtualNetworkName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' = {
  name: SubnetName
  parent: virtualNetwork
  properties: SubnetProperties
}

// ============================================================================================

output SubnetId string = subnet.id
output SubnetProperties object = subnet.properties

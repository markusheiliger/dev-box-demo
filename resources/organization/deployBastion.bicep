
targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

// ============================================================================================

var BastionSubnetDefinition = first(filter(OrganizationDefinition.network.subnets, subnet => subnet.name == 'AzureBastionSubnet'))
var BastionResourceName = '${OrganizationDefinition.name}-BH'

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: OrganizationDefinition.name
}

resource bastionSubNet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: BastionSubnetDefinition.name
  parent: virtualNetwork
}

resource bastionPIP 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: BastionResourceName
  location: OrganizationDefinition.location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource bastion 'Microsoft.Network/bastionHosts@2022-07-01' = {
  name: BastionResourceName
  location: OrganizationDefinition.location
  sku: {
    name: 'Basic'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: bastionPIP.id
          }
          subnet: {
            id: bastionSubNet.id
          }
        }
      }
    ]
  }
}



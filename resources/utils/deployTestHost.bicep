targetScope = 'resourceGroup'

// ============================================================================================

param VNetName string
param SNetName string = 'default'

param Username string = 'godfather'
param Password string = 'T00ManySecrets'

// ============================================================================================

var ResourceName = '${VNetName}-TH'

#disable-next-line no-loc-expr-outside-params
var ResourceLocation = resourceGroup().location

// ============================================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: VNetName
}

resource snet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: SNetName
  parent: vnet
}

resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: ResourceName
  location: ResourceLocation
  properties: {
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          subnet: {
            id: snet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: ResourceName
  location: ResourceLocation
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: ResourceName
  location: ResourceLocation
  tags: {
    Username: Username
    Password: Password
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B4ms'
    }
    storageProfile: {
      osDisk: {
        name: ResourceName
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-Datacenter'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    osProfile: {
      computerName: 'testhost'
      adminUsername: Username
      adminPassword: Password
    }
  }
}

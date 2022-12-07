targetScope = 'resourceGroup'

// ============================================================================================

param VmAdminUsername string

@secure()
param VmAdminPassword string

param VmSize string = 'Standard_D2_v3'
// ============================================================================================

#disable-next-line no-loc-expr-outside-params
var ResourceLocation = resourceGroup().location
var ResourcePrefix = uniqueString(resourceGroup().id)

var EnvironmentNetworkIdSegments = split(resourceGroup().tags.EnvironmentNetworkId, '/')

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-05-01' existing = {
  name: last(EnvironmentNetworkIdSegments)
  scope: resourceGroup(EnvironmentNetworkIdSegments[2], EnvironmentNetworkIdSegments[4])
}

resource defaultSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' existing = {
  name : 'default'
  parent: virtualNetwork
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: ResourcePrefix
  location: ResourceLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: defaultSubnet.id
          }
        }
      }
    ]
  }
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: ResourcePrefix
  location: ResourceLocation
  properties: {
    hardwareProfile: {
      vmSize: VmSize
    }
    osProfile: {
      computerName: ResourcePrefix
      adminUsername: VmAdminUsername
      adminPassword: VmAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2019-Datacenter'
        version: 'latest'
      }
      osDisk: {
        name: '${ResourcePrefix}-OsDisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: 1024
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
  }
}

targetScope = 'resourceGroup'

// ============================================================================================

param JumpHostNetworkId string

param JumpHostPrefix string

param JumpHostLocation string = resourceGroup().location

param JumpHostUsername string = 'godfather'

@secure()
#disable-next-line secure-parameter-default
param JumpHostPassword string = 'T00ManySecrets'

// ============================================================================================

var JumpHostName = '${JumpHostPrefix}-JH'

// ============================================================================================

resource publicIP 'Microsoft.Network/publicIPAddresses@2022-07-01' = {
  name: JumpHostName
  location: JumpHostLocation
  properties: {
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: '${toLower(JumpHostName)}-${uniqueString(resourceGroup().id)}'
    }
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: JumpHostName
  location: JumpHostLocation
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: JumpHostNetworkId
          }
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}
resource nsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: JumpHostName
  location: JumpHostLocation
  properties: {
    securityRules: [
      {
        name: 'RDP'
        properties: {
          priority: 1000
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

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: JumpHostName
  location: JumpHostLocation
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5'
    }
    osProfile: {
      computerName: 'JumpHost'
      adminUsername: JumpHostUsername
      adminPassword: JumpHostPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-smalldisk-g2'
        version: 'latest'
      }
      osDisk: {
        name: JumpHostName
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
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

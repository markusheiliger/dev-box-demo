targetScope = 'resourceGroup'

// ============================================================================================

param GatewayNetworkId string

param GatewayDefinition object

param OrganizationDefinition object

param ProjectDefinition object

// ============================================================================================

var PrivateIPSegments = split(split(ProjectDefinition.ipRange, '/')[0], '.')
var PrivateIP = '${join(take(PrivateIPSegments, 3), '.')}.${int(last(PrivateIPSegments))+4}'

// ============================================================================================

resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: '${ProjectDefinition.name}-GW'
  location: OrganizationDefinition.location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: GatewayNetworkId
          }
          privateIPAllocationMethod: 'Static'
          privateIPAddress: PrivateIP
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
    enableIPForwarding: true
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: '${ProjectDefinition.name}-GW'
  location: OrganizationDefinition.location
  properties: {
    securityRules: [
      {
        name: 'SSH'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'AllowWireguard'
        properties: {
          priority: 1200
          protocol: 'Udp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

resource publicIP 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: '${ProjectDefinition.name}-GW'
  location: OrganizationDefinition.location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'static'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: guid(resourceGroup().id)
    }
    idleTimeoutInMinutes: 4
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: '${ProjectDefinition.name}-GW'
  location: OrganizationDefinition.location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    storageProfile: {
      osDisk: {
        name: '${ProjectDefinition.name}-GW'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-minimal-jammy'
        sku: 'minimal-22_04-lts'
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
      computerName: 'Gateway'
      adminUsername: GatewayDefinition.username
      adminPassword: GatewayDefinition.password
    }
  }
}

resource vmInit 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  name: 'Init'
  location: OrganizationDefinition.location
  parent: vm
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {      
      script: loadFileAsBase64('deployProject-Gateway.sh')
    }
  }
}

// ============================================================================================

output GatewayIP string = PrivateIP

targetScope = 'resourceGroup'

// ============================================================================================

param OrganizationDefinition object
param ProjectDefinition object

// ============================================================================================

var ResourceName = '${ProjectDefinition.name}-WG'

var WireguardDefinition = contains(ProjectDefinition, 'wireguard') ? ProjectDefinition.wireguard : {}
var WireguardIPSegments = split(split(snet.properties.addressPrefix, '/')[0],'.')
var WireguardIP = '${join(take(WireguardIPSegments, 3),'.')}.${int(any(last(WireguardIPSegments)))+4}'

var WireguardInitScriptsBaseUri = 'https://raw.githubusercontent.com/markusheiliger/dev-box-demo/main/resources/project/scripts/'
var WireguardInitScriptNames = [ 'initMachine.sh', 'setupWireGuard.sh' ]

var WireguardInitCommand = join(filter([
  './initMachine.sh'
  './setupWireGuard.sh -e \'${wireguardPIP.properties.ipAddress}\' -r \'${WireguardDefinition.ipRange}\' -p 1 -a \'${vnet.properties.addressSpace}\''
  // 'sudo shutdown -r 1'
], item => !empty(item)), ' && ')

// ============================================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: ProjectDefinition.name
}

resource snet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: 'wireguard'
  parent: vnet
}

resource wireguardPIP 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: ResourceName
  location: OrganizationDefinition.location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource wireguardNSG 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: ResourceName
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
          sourceAddressPrefix: OrganizationDefinition.network.ipRange
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'Wireguard'
        properties: {
          priority: 1010
          protocol: 'Udp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '51820'
        }
      }
    ]
  }
}

resource wireguardNIC 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: ResourceName
  location: OrganizationDefinition.location
  properties: {
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          subnet: {
            id: snet.id
          }
          privateIPAddress: WireguardIP
          privateIPAllocationMethod: 'Static'
          publicIPAddress: {
            id: wireguardPIP.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: wireguardNSG.id
    }
    enableIPForwarding: true
  }
}

resource availabilitySet 'Microsoft.Compute/availabilitySets@2022-08-01' = {
  name: ResourceName
  location: OrganizationDefinition.location
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 2
  }
}

resource wireguard 'Microsoft.Compute/virtualMachines@2021-11-01' = {
  name: ResourceName
  location: OrganizationDefinition.location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    availabilitySet: {
      id: availabilitySet.id
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
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-minimal-jammy'
        sku: 'minimal-22_04-lts'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: wireguardNIC.id
        }
      ]
    }
    osProfile: {
      computerName: 'wireguard'
      adminUsername: WireguardDefinition.username
      adminPassword: WireguardDefinition.password
    }
  }
}

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vnet.id, wireguard.id, contributorRoleDefinition.id)
  properties: {
    principalId: wireguard.identity.principalId
    roleDefinitionId: contributorRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}

resource wireguardInit 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  name: 'Init'
  location: OrganizationDefinition.location
  dependsOn: [
    contributorRoleAssignment
  ]
  parent: wireguard
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    forceUpdateTag: guid(deployment().name)
    autoUpgradeMinorVersion: true
    settings: {      
      fileUris: map(WireguardInitScriptNames, name => uri(WireguardInitScriptsBaseUri, name))
      commandToExecute: WireguardInitCommand
    }
  }
}

// ============================================================================================

output WireguardIP string = wireguardNIC.properties.ipConfigurations[0].properties.privateIPAddress

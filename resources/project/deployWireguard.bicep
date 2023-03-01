targetScope = 'resourceGroup'

// ============================================================================================

param OrganizationDefinition object
param ProjectDefinition object

// ============================================================================================

var ResourceName = '${ProjectDefinition.name}-WG'

var WireguardDefinition = contains(ProjectDefinition, 'wireguard') ? ProjectDefinition.wireguard : {}
var WireguardIPSegments = split(split(wireguardSnet.properties.addressPrefix, '/')[0], '.')
var WireguardIP = '${join(take(WireguardIPSegments, 3),'.')}.${int(any(last(WireguardIPSegments)))+4}'

var WireguardInitScriptsBaseUri = 'https://raw.githubusercontent.com/markusheiliger/dev-box-demo/main/resources/project/scripts/'
var WireguardInitScriptNames = [ 'initMachine.sh', 'setupWireGuard.sh' ]

var WireguardArguments = join([
  '-e \'${wireguardPIP.properties.ipAddress}\''                                           // Endpoint (the Wireguard public endpoint)
  '-h \'${ProjectDefinition.network.ipRange}\''                                           // Home Range (the Project's IPRange)
  '-v \'${WireguardDefinition.ipRange}\''                                                 // Virtual Range (internal Wireguard IPRange)
  join(map(WireguardDefinition.islands, island => '-i \'${island.ipRange}\''), ' ')       // Island Ranges (list of Island IPRanges)
], ' ')

var WireguardInitCommand = join(filter([
  './initMachine.sh'
  './setupWireGuard.sh ${WireguardArguments}'
  'sudo shutdown -r 1'
], item => !empty(item)), ' && ')

var WireguardInboundStatic = [
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
    name: 'Wireguard-Tunnel'
    properties: {
      priority: 2000
      protocol: 'Udp'
      access: 'Allow'
      direction: 'Inbound'
      sourceAddressPrefix: 'Internet'
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
      destinationPortRange: '51820'
    }
  }
]

var WireguardInboundIslands = [for i in range(1, length(WireguardDefinition.islands)): {
  name: 'Wireguard-Island${i}'
  properties: {
    priority: (2000 + i)
    protocol: '*'
    access: 'Allow'
    direction: 'Inbound'
    sourceAddressPrefix: 'VirtualNetwork'
    sourcePortRange: '*'
    destinationAddressPrefix: WireguardDefinition.islands[i-1].ipRange
    destinationPortRange: '*'
  }
}]

// ============================================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: ProjectDefinition.name
}

resource wireguardSnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: 'wireguard'
  parent: vnet
}

resource defaultSnet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: 'default'
  parent: vnet
}

resource defaultRoutes 'Microsoft.Network/routeTables@2022-07-01' existing = {
  name: '${ProjectDefinition.name}-RT-${defaultSnet.name}'
}

resource defaultRoute 'Microsoft.Network/routeTables/routes@2022-07-01' = [for (IslandDefintion, IslandIndex) in WireguardDefinition.islands : {
  name: 'Island${IslandIndex + 1}'
  parent: defaultRoutes
  properties: {
    addressPrefix: IslandDefintion.ipRange
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: wireguardNIC.properties.ipConfigurations[0].properties.privateIPAddress
  }
}]

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
    securityRules: concat(WireguardInboundStatic, WireguardInboundIslands)
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
            id: wireguardSnet.id
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

resource wireguardTags 'Microsoft.Resources/tags@2022-09-01' = {
  name: 'default'
  scope: wireguard
  properties: {
    tags: {
      WireguardArguments: WireguardArguments
    }
  }
}

resource wireguardInit 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  name: 'Init'
  location: OrganizationDefinition.location
  parent: wireguard
  dependsOn: [
    contributorRoleAssignment
  ]
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

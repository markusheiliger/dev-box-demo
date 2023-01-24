targetScope = 'resourceGroup'

// ============================================================================================

param SubNetId string

@description('The organization defintion to process')
param OrganizationDefinition object

@description('The project defintion to process')
param ProjectDefinition object

param DnsForwards array = []
param DnsClients array = []

param NetForwards array = []
param NetBlocks array = []

// ============================================================================================

var VirtualNetworkId = join(take(split(SubNetId, '/'), 9),'/')
var ResourceName = '${last(split(VirtualNetworkId, '/'))}-GW'

var GatewayIPSegments = split(first(split(snet.properties.addressPrefix, '/')),'.')
var GatewayIP = '${join(take(GatewayIPSegments, 3),'.')}.${int(last(GatewayIPSegments))+4}'

var SetupDnsForwarderEnabled = length(DnsForwards) > 0
var SetupDnsForwarderCommand = trim('./setupDnsForwarder.sh -n ${VirtualNetworkId} ${length(DnsForwards) > 0 ? '-f' : ''} ${join(DnsForwards, ' -f ')} ${length(DnsClients) > 0 ? '-c' : ''} ${join(DnsClients, ' -c ')} | tee ./setupDnsForwarder.log')

var SetupNetForwarderEnabled = (length(NetForwards) + length(NetBlocks)) > 0
var SetupNetForwarderCommand = trim('./setupNetForwarder.sh -n ${VirtualNetworkId} ${length(NetForwards) > 0 ? '-f' : ''} ${join(NetForwards, ' -f ')} ${length(NetBlocks) > 0 ? '-b' : ''} ${join(NetBlocks, ' -b ')} | tee ./setupNetForwarder.log')

var GatewayInitScripts = [ 
  'https://raw.githubusercontent.com/markusheiliger/dev-box-demo/main/resources/scripts/initMachine.sh' 
  'https://raw.githubusercontent.com/markusheiliger/dev-box-demo/main/resources/scripts/setupDnsForwarder.sh' 
  'https://raw.githubusercontent.com/markusheiliger/dev-box-demo/main/resources/scripts/setupNetForwarder.sh' 
  'https://raw.githubusercontent.com/markusheiliger/dev-box-demo/main/resources/scripts/setupWireGuard.sh' 
]

var GatewayInitCommand = join(filter([
  './initMachine.sh'
  SetupDnsForwarderEnabled ? SetupDnsForwarderCommand : ''
  SetupNetForwarderEnabled ? SetupNetForwarderCommand : ''
], item => !empty(item)), ' && ')

// ============================================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: last(split(VirtualNetworkId, '/'))
}

resource snet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: last(split(SubNetId, '/'))
  parent: vnet
}

resource pip 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: ResourceName
  location: OrganizationDefinition.location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'dynamic'
    publicIPAddressVersion: 'IPv4'
    dnsSettings: {
      domainNameLabel: 'gw-${guid(resourceGroup().id)}'
    }
    idleTimeoutInMinutes: 4
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: ResourceName
  location: OrganizationDefinition.location
  properties: {
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          subnet: {
            id: SubNetId
          }
          privateIPAddress: GatewayIP
          privateIPAllocationMethod: 'Static'
          publicIPAddress: {
            id: pip.id
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
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
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

resource gateway 'Microsoft.Compute/virtualMachines@2021-11-01' = {
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
          id: nic.id
        }
      ]
    }
    osProfile: {
      computerName: ResourceName
      adminUsername: ProjectDefinition.gateway.username
      adminPassword: ProjectDefinition.gateway.password
    }
  }
}

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(vnet.id, gateway.id, contributorRoleDefinition.id)
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: gateway.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource gatewayInit 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  name: 'Init'
  location: OrganizationDefinition.location
  parent: gateway
  dependsOn: [
    contributorRoleAssignment
  ]
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {      
      fileUris: GatewayInitScripts
      commandToExecute: GatewayInitCommand
    }
  }
}

// ============================================================================================

output GatewayIp string = first(nic.properties.ipConfigurations).properties.privateIPAddress

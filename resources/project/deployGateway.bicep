targetScope = 'resourceGroup'

// ============================================================================================

param OrganizationDefinition object
param OrganizationGatewayIP string
param ProjectDefinition object

// ============================================================================================

var ResourceName = '${ProjectDefinition.name}-GW'

var GatewayDefinition = contains(ProjectDefinition, 'gateway') ? ProjectDefinition.gateway : {}
var GatewayIPSegments = split(split(defaultSubNetwork.properties.addressPrefix, '/')[0],'.')
var GatewayIP = '${join(take(GatewayIPSegments, 3),'.')}.${int(any(last(GatewayIPSegments)))+4}'

var GatewayInitScriptsBaseUri = 'https://raw.githubusercontent.com/markusheiliger/dev-box-demo/main/resources/project/scripts/'
var GatewayInitScriptNames = [ 'initMachine.sh', 'setupDnsForwarder.sh', 'setupNetForwarder.sh', 'setupWireGuard.sh' ]

var GatewayInitCommand = join(filter([
  './initMachine.sh'
  './setupDnsForwarder.sh -n \'${virtualNetwork.id}\' -f \'168.63.129.16\' -f \'${OrganizationGatewayIP}\''
  './setupNetForwarder.sh -n \'${virtualNetwork.id}\' ${join(map(ProjectDefinition.environments, env => '-f \'${env.ipRange}\''), ' ')}'
  './setupWireGuard.sh -e \'${gatewayPIP.properties.ipAddress}\' ${join(map(virtualNetwork.properties.addressSpace.addressPrefixes, p => '-a \'${p}\''),' ')}'
], item => !empty(item)), ' && ')

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: ProjectDefinition.name
}

resource defaultSubNetwork 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: 'default'
  parent: virtualNetwork
}

resource gatewayPIP 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
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

resource gatewayNSG 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
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
        name: 'Gateway'
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

resource gatewayNIC 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: ResourceName
  location: OrganizationDefinition.location
  properties: {
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          subnet: {
            id: defaultSubNetwork.id
          }
          privateIPAddress: GatewayIP
          privateIPAllocationMethod: 'Static'
          publicIPAddress: {
            id: gatewayPIP.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: gatewayNSG.id
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
          id: gatewayNIC.id
        }
      ]
    }
    osProfile: {
      computerName: 'gateway'
      adminUsername: GatewayDefinition.username
      adminPassword: GatewayDefinition.password
    }
  }
}

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(virtualNetwork.id, gateway.id, contributorRoleDefinition.id)
  properties: {
    principalId: gateway.identity.principalId
    roleDefinitionId: contributorRoleDefinition.id
    principalType: 'ServicePrincipal'
  }
}

resource gatewayInit 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
  name: 'Init'
  location: OrganizationDefinition.location
  dependsOn: [
    contributorRoleAssignment
  ]
  parent: gateway
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    forceUpdateTag: guid(deployment().name)
    autoUpgradeMinorVersion: true
    settings: {      
      fileUris: map(GatewayInitScriptNames, name => uri(GatewayInitScriptsBaseUri, name))
      commandToExecute: GatewayInitCommand
    }
  }
}

// ============================================================================================

output GatewayIP string = gatewayNIC.properties.ipConfigurations[0].properties.privateIPAddress

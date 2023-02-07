targetScope = 'resourceGroup'

// ============================================================================================

param OrganizationDefinition object
param OrganizationInfo object

param ProjectDefinition object

param DnsForwards array = []
param DnsClients array = []

param NetForwards array = []
param NetBlocks array = []

// ============================================================================================

var ResourceName = '${ProjectDefinition.name}-GW'

var GatewayIPSegments = split(any(first(split(snet.properties.addressPrefix, '/'))),'.')
var GatewayIP = '${join(take(GatewayIPSegments, 3),'.')}.${int(any(last(GatewayIPSegments)))+4}'

var SetupDnsForwarderArguments = union(map(DnsForwards, item => '-f "${string(item)}"'), map(DnsClients, item => '-c "${string(item)}"'))
var SetupDnsForwarderEnabled = length(DnsForwards) > 0
var SetupDnsForwarderCommand = trim('./setupDnsForwarder.sh -n "${vnet.id}" ${join(SetupDnsForwarderArguments, ' ')} | tee ./setupDnsForwarder.log')

var SetupNetForwarderArguments = union(map(NetForwards, item => '-f "${string(item)}"'), map(NetBlocks, item => '-b "${string(item)}"'))
var SetupNetForwarderEnabled = (length(NetForwards) + length(NetBlocks)) > 0
var SetupNetForwarderCommand = trim('./setupNetForwarder.sh -n "${vnet.id}" ${join(SetupNetForwarderArguments, ' ')} | tee ./setupNetForwarder.log')

var GatewayInitScriptsBaseUri = 'https://raw.githubusercontent.com/markusheiliger/dev-box-demo/main/resources/project/scripts/'
var GatewayInitScriptNames = [ 'initMachine.sh', 'setupDnsForwarder.sh', 'setupNetForwarder.sh', 'setupWireGuard.sh' ]

var GatewayInitCommand = join(filter([
  './initMachine.sh'
  SetupDnsForwarderEnabled ? SetupDnsForwarderCommand : ''
  SetupNetForwarderEnabled ? SetupNetForwarderCommand : ''
], item => !empty(item)), ' && ')

// ============================================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: ProjectDefinition.name
}

resource snet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: 'default'
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
            id: snet.id
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

// resource gatewayDiag 'Microsoft.Compute/virtualMachines/extensions@2022-08-01' = {
//   name: 'Diag'
//   location: OrganizationDefinition.location
//   parent: gateway
//   dependsOn: [
//     contributorRoleAssignment
//   ]
//   properties: {
//     publisher: 'Microsoft.EnterpriseCloud.Monitoring'
//     type: 'MicrosoftMonitoringAgent'
//     typeHandlerVersion: '1.0'
//     autoUpgradeMinorVersion: true
//     settings: {
//         workspaceId: OrganizationInfo.WorkspaceId
//     }
//     protectedSettings: {
//         workspaceKey: listKeys(OrganizationInfo.WorkspaceId, '2022-10-01').primarySharedKey
//     }
//   }
// }

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
    forceUpdateTag: guid(deployment().name)
    autoUpgradeMinorVersion: true
    settings: {      
      fileUris: map(GatewayInitScriptNames, name => uri(GatewayInitScriptsBaseUri, name))
      commandToExecute: GatewayInitCommand
    }
  }
}

// ============================================================================================

output GatewayIP string = nic.properties.ipConfigurations[0].properties.privateIPAddress

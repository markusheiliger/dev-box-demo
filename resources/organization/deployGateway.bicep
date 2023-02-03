
targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

// ============================================================================================

var FirewallDnsServers = union(['168.63.129.16'], map(
  flatten(map(any(virtualNetwork.properties.virtualNetworkPeerings), peer => map(peer.properties.remoteVirtualNetworkAddressSpace.addressPrefixes, addressPrefix => any(first(split(addressPrefix, '/')))))),
  address => '${join(take(split(address, '.'), 3), '.')}.${int(any(last(split(address, '.'))))+4}'))

var FirewallSubnetDefinition = any(first(filter(OrganizationDefinition.network.subnets, subnet => subnet.name == 'AzureFirewallSubnet')))
var FirewallResourceName = '${OrganizationDefinition.name}-FW'

// ============================================================================================

resource routes 'Microsoft.Network/routeTables@2022-07-01' existing = {
  name: OrganizationDefinition.name
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: OrganizationDefinition.name
}

resource firewallSubNet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: FirewallSubnetDefinition.name
  parent: virtualNetwork
}

resource firewallLocalSourceIps 'Microsoft.Network/ipGroups@2022-01-01' = {
  name: '${FirewallResourceName}-LOCAL'
  location: OrganizationDefinition.location
  properties: {
    ipAddresses: virtualNetwork.properties.addressSpace.addressPrefixes
  }
}

resource firewallPeeredSourceIps 'Microsoft.Network/ipGroups@2022-01-01' = {
  name: '${FirewallResourceName}-PEERED'
  location: OrganizationDefinition.location
  dependsOn: [
    firewallLocalSourceIps
  ]
  properties: {
    ipAddresses: flatten(map(virtualNetwork.properties.virtualNetworkPeerings, peer => peer.properties.remoteVirtualNetworkAddressSpace.addressPrefixes))
  }
}

resource firewallRoute 'Microsoft.Network/routeTables/routes@2022-07-01' = {
  name: FirewallResourceName
  parent: routes
  properties: {
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: any(first(firewall.properties.ipConfigurations)).properties.privateIPAddress
    addressPrefix: '0.0.0.0/0'
  }
}

resource firewallPIP 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: FirewallResourceName
  location: OrganizationDefinition.location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

resource firewallPolicy 'Microsoft.Network/firewallPolicies@2022-07-01' = {
  name: FirewallResourceName
  location: OrganizationDefinition.location
  dependsOn: [
    firewallLocalSourceIps
    firewallPeeredSourceIps
  ]
  properties: {
    threatIntelMode: 'Alert'
    dnsSettings: {
      enableProxy: true
      servers: FirewallDnsServers
    }
  }
}

resource defaultNetworkRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-01-01' = {
  parent: firewallPolicy
  name: 'DefaultNetworkRuleCollectionGroup'
  properties: {
    priority: 200
    ruleCollections: [
      {
        name: 'org-services'
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        priority: 1250
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'time-windows-address'
            ipProtocols: [ 'UDP' ]
            sourceIpGroups: [ firewallLocalSourceIps.id, firewallPeeredSourceIps.id ]
            destinationAddresses: [ '13.86.101.172' ]
            destinationPorts: [ '123' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'time-windows-fqdn'
            ipProtocols: [ 'UDP' ]
            sourceIpGroups: [ firewallLocalSourceIps.id, firewallPeeredSourceIps.id ]
            destinationFqdns: [ 'time.windows.com' ]
            destinationPorts: [ '123' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'microsoft-login'
            ipProtocols: [ 'TCP' ]
            sourceIpGroups: [ firewallLocalSourceIps.id, firewallPeeredSourceIps.id ]
            destinationFqdns: [ 
              split(environment().authentication.loginEndpoint, '/')[2] 
              'login.windows.net'
            ]
            destinationPorts: [ '443' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'microsoft-connect'
            ipProtocols: [ 'TCP' ]
            sourceIpGroups: [ firewallLocalSourceIps.id, firewallPeeredSourceIps.id ]
            destinationFqdns: [ 'www.msftconnecttest.com' ]
            destinationPorts: [ '443' ]
          }
        ]
      }
      {
        name: 'org-virtualdesktop'
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        priority: 1260
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'avd-common'
            ipProtocols: [ 'TCP' ]
            sourceIpGroups: [ firewallPeeredSourceIps.id ]
            destinationFqdns: [
              'oneocsp.microsoft.com'
              'www.microsoft.com'
            ]
            destinationPorts: [ '80' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'avd-storage'
            ipProtocols: [ 'TCP' ]
            sourceIpGroups: [ firewallPeeredSourceIps.id ]
            destinationFqdns: [
              'mrsglobalsteus2prod.blob.${environment().suffixes.storage}'
              'wvdportalstorageblob.blob.${environment().suffixes.storage}'
            ]
            destinationPorts: [ '443' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'avd-services'
            ipProtocols: [ 'TCP' ]
            sourceIpGroups: [ firewallPeeredSourceIps.id ]
            destinationAddresses: [
              'WindowsVirtualDesktop'
              'AzureFrontDoor.Frontend'
              'AzureMonitor'
            ]
            destinationPorts: [ '443' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'avd-kms'
            ipProtocols: [ 'TCP' ]
            sourceIpGroups: [ firewallPeeredSourceIps.id ]
            destinationFqdns: [
              'azkms.${environment().suffixes.storage}'
              'kms.${environment().suffixes.storage}'
            ]
            destinationPorts: [ '1688' ]
          }      
          {
            ruleType: 'NetworkRule'
            name: 'avd-devices'
            ipProtocols: [ 'TCP' ]
            sourceIpGroups: [ firewallPeeredSourceIps.id ]
            destinationFqdns: [
              'global.azure-devices-provisioning.net'
            ]
            destinationPorts: [ '5671' ]
          }   
          {
            ruleType: 'NetworkRule'
            name: 'avd-fastpath-ip'
            ipProtocols: [ 'UDP' ]
            sourceIpGroups: [ firewallPeeredSourceIps.id ]
            destinationAddresses: [ '13.107.17.41' ]
            destinationPorts: [ '3478' ]
          }  
          {
            ruleType: 'NetworkRule'
            name: 'avd-fastpath-fqdn'
            ipProtocols: [ 'UDP' ]
            sourceIpGroups: [ firewallPeeredSourceIps.id ]
            destinationFqdns: [ 'stun.azure.com' ]
            destinationPorts: [ '3478' ]
          }  
        ]
      }
    ]
  }
}

resource defaultApplicationRuleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2022-01-01' = {
  parent: firewallPolicy
  name: 'DefaultApplicationRuleCollectionGroup'
  dependsOn: [
    defaultNetworkRuleCollectionGroup
  ]
  properties: {
    priority: 300
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'org-services'
        priority: 1000
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'WindowsUpdate'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
              {
                protocolType: 'Http'
                port: 80
              }
            ]
            fqdnTags: [
              'WindowsUpdate'
            ]
            terminateTLS: false
            sourceIpGroups: [ firewallLocalSourceIps.id, firewallPeeredSourceIps.id ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'WindowsVirtualDesktop'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            fqdnTags: [
              'WindowsVirtualDesktop'
              'WindowsDiagnostics'
              'MicrosoftActiveProtectionService'
            ]
            destinationAddresses: [
              '*.events.data.microsoft.com'
              '*.sfx.ms'
              '*.digicert.com'
              '*.azure-dns.com'
              '*.azure-dns.net'
            ]
            terminateTLS: false
            sourceIpGroups: [ firewallPeeredSourceIps.id ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        action: {
          type: 'Allow'
        }
        name: 'org-browse'
        priority: 1202
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'general'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
              {
                protocolType: 'Http'
                port: 80
              }
            ]
            webCategories: [
              'ComputersAndTechnology'
              'InformationSecurity'
              'WebRepositoryAndStorage'
            ]
            terminateTLS: false
            sourceIpGroups: [ firewallLocalSourceIps.id, firewallPeeredSourceIps.id ]
          }
        ]
      }
    ]
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2022-07-01' = {
  name: FirewallResourceName
  location: OrganizationDefinition.location
  dependsOn: [
    defaultNetworkRuleCollectionGroup
    defaultApplicationRuleCollectionGroup
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          subnet:{
            id: firewallSubNet.id
          }
          publicIPAddress: {
            id: firewallPIP.id
          }
        }
      }
    ]
    firewallPolicy: {
      id: firewallPolicy.id
    }
  }
}

// ============================================================================================

output GatewayIP string = any(first(firewall.properties.ipConfigurations)).properties.privateIPAddress

targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

param OrganizationNetworkId string

param OrganizationWorkspaceId string

// ============================================================================================

var OrganizationNetworkIdSegments = split(OrganizationNetworkId, '/')

var FirewallPIPCount = 3

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-05-01' existing = {
  name: last(OrganizationNetworkIdSegments)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' = {
  name: 'AzureFirewallSubnet'
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.0.0.128/26'
  }
}

resource firewallPIP 'Microsoft.Network/publicIPAddresses@2022-01-01' = [for i in range(0, FirewallPIPCount): {
  name: '${OrganizationDefinition.name}-FW-PIP-${padLeft(i, 2, '0')}'
  location: OrganizationDefinition.location
  sku: {
    name: 'Standard'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}]

resource firewallPOL 'Microsoft.Network/firewallPolicies@2022-01-01' = {
  name: '${OrganizationDefinition.name}-FW-POL'
  location: OrganizationDefinition.location
  properties: {
    sku: {
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
    insights: {
      isEnabled: true
      retentionDays: 30
      logAnalyticsResources: {
        defaultWorkspaceId: {
          id: OrganizationWorkspaceId
        }
      }
    }
  }

  resource defaultNetworkRuleCollectionGroup 'ruleCollectionGroups@2022-01-01' = {
    name: 'DefaultNetworkRuleCollectionGroup'
    properties: {
      priority: 200
      ruleCollections: [
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          name: 'org-wide-allowed'
          priority: 100
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'NetworkRule'
              name: 'DNS'
              description: 'Allow DNS outbound'
              ipProtocols: [
                'UDP'
              ]
              sourceAddresses: [
                '*'
              ]
              sourceIpGroups: []
              destinationAddresses: [
                '*'
              ]
              destinationIpGroups: []
              destinationFqdns: []
              destinationPorts: [
                '53'
              ]
            }
            {
              ruleType: 'NetworkRule'
              name: 'WEB'
              description: 'Allow WEB outbound'
              ipProtocols: [
                'TCP'
              ]
              sourceAddresses: [
                '*'
              ]
              sourceIpGroups: []
              destinationAddresses: [
                '*'
              ]
              destinationIpGroups: []
              destinationFqdns: []
              destinationPorts: [
                '80'
                '443'
              ]
            }
          ]
        }
        {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          name: 'avd-extended-allowed'
          priority: 200
          action: {
            type: 'Allow'
          }
          rules: [
            {
              ruleType: 'NetworkRule'
              name: 'Registration'
              description: 'Allow AVD registration outbound'
              ipProtocols: [
                'TCP'
              ]
              sourceAddresses: [
                '*'
              ]
              sourceIpGroups: []
              destinationAddresses: [
                '*'
              ]
              destinationIpGroups: []
              destinationFqdns: []
              destinationPorts: [
                '5671'
              ]
            }
          ]
        }
      ]
    }
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2022-01-01' = {
  name: '${OrganizationDefinition.name}-FW'
  location: OrganizationDefinition.location
  zones: [
    '1'
    '2'
    '3'
  ]
  dependsOn: [
    // This helps prevent multiple PUT updates happening to the firewall causing a CONFLICT race condition
    // Ref: https://learn.microsoft.com/azure/firewall-manager/quick-firewall-policy
    firewallPOL::defaultNetworkRuleCollectionGroup
    // fwPolicy::defaultNetworkRuleCollectionGroup
  ]
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    firewallPolicy: {
      id: firewallPOL.id
    }
    ipConfigurations: [for i in range(0, FirewallPIPCount): {
      name: firewallPIP[i].name
      properties: {
        subnet: (0 == i) ? {
          id: subnet.id
        } : null
        publicIPAddress: {
          id: firewallPIP[i].id
        }
      }
    }]
  }
}

resource firewallLA 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${OrganizationDefinition.name}-FW-LA'
  scope: firewall
  properties: {
    workspaceId: OrganizationWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output GatewayIPAddress string = firewall.properties.ipConfigurations[0].properties.privateIPAddress

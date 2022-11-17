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

module createSubnet 'createSubnet.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('createSubnet', 'AzureFirewallSubnet')}'
  scope: resourceGroup(OrganizationNetworkIdSegments[2], OrganizationNetworkIdSegments[4])
  params: {
    VirtualNetworkName: last(OrganizationNetworkIdSegments)
    SubnetName: 'AzureFirewallSubnet'
    SubnetProperties: {
      addressPrefix: '10.0.0.128/26'
    }
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
    threatIntelMode: 'Deny'
    insights: {
      isEnabled: true
      retentionDays: 30
      logAnalyticsResources: {
        defaultWorkspaceId: {
          id: OrganizationWorkspaceId
        }
      }
    }
    threatIntelWhitelist: {
      fqdns: []
      ipAddresses: []
    }
    intrusionDetection: null // Only valid on Premium tier sku
    dnsSettings: {
      servers: []
      enableProxy: true
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
              description: 'Allow DNS outbound (for simplicity, adjust as needed)'
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
          id: createSubnet.outputs.SubnetId
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

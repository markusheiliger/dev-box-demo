targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

param OrganizationNetworkId string

param OrganizationWorkspaceId string

// ============================================================================================

var OrganizationNetworkIdSegments = split(OrganizationNetworkId, '/')

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-05-01' existing = {
  name: last(OrganizationNetworkIdSegments)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' = {
  name: 'AzureGatewaySubnet'
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.0.0.96/27'
  }
}

resource gatewayPIP 'Microsoft.Network/publicIPAddresses@2022-05-01' ={
  name: '${OrganizationDefinition.name}-GW-PIP'
  location: OrganizationDefinition.location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource gateway 'Microsoft.Network/virtualNetworkGateways@2022-05-01' = {
  name: '${OrganizationDefinition.name}-GW'
  location: OrganizationDefinition.location
  properties: {
    sku: {
      name: 'VpnGw2AZ'
      tier: 'VpnGw2AZ'
    }
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    vpnGatewayGeneration: 'Generation2'
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: gatewayPIP.id
          }          
          subnet: {
             id: subnet.id
          }
        }
      }
    ]

  }
}

resource gatewayLA 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${OrganizationDefinition.name}-GW-LA'
  scope: gateway
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

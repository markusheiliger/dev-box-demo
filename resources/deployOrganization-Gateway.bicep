targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

param OrganizationNetworkId string

param OrganizationWorkspaceId string

// ============================================================================================

var OrganizationNetworkIdSegments = split(OrganizationNetworkId, '/')

// ============================================================================================

module createSubnet 'createSubnet.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('createSubnet', 'GatewaySubnet')}'
  scope: resourceGroup(OrganizationNetworkIdSegments[2], OrganizationNetworkIdSegments[4])
  params: {
    VirtualNetworkName: last(OrganizationNetworkIdSegments)
    SubnetName: 'AzureBastionSubnet'
    SubnetProperties: {
      addressPrefix: '10.0.0.96/27'
    }
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
             id: createSubnet.outputs.SubnetId
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

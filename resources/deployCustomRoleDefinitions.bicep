targetScope = 'subscription'

// ============================================================================================

resource environmentDeployerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: 'b2780688-3ab3-45cc-83d2-f1c264322d93'
  properties: {
    roleName: 'Custom Role - DevCenter Environment Deployer'
    description: 'Grant permissions to join networks and manager private DNS zones'
    type: 'customRole'
    permissions: [
      {
        actions: [
          'Microsoft.Authorization/*/read'
          'Microsoft.Insights/alertRules/*'
          'Microsoft.Network/dnsZones/*'
          'Microsoft.ResourceHealth/availabilityStatuses/read'
          'Microsoft.Resources/deployments/*'
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.Support/*'
          'Microsoft.Network/virtualNetworks/read'
          'Microsoft.Network/virtualNetworks/subnets/join/action'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
    assignableScopes: [
      subscription().id
    ]
  }
}

// ============================================================================================

output EnvironmentDeployerRoleDefinition string = environmentDeployerRoleDefinition.name

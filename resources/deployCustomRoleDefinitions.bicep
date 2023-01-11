targetScope = 'subscription'

// ============================================================================================

var environmentDeployerRolePermissions = [
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

var environmentDeployerRoleScopes = [
  subscription().id
]

// ============================================================================================

resource environmentDeployerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(string(environmentDeployerRolePermissions), string(environmentDeployerRoleScopes))
  scope: subscription()
  properties: {
    roleName: 'Custom Role - DevCenter Environment Deployer for subscription ${subscription().subscriptionId}'
    description: 'Grant permissions to join networks and manager private DNS zones'
    type: 'CustomRole'
    permissions: environmentDeployerRolePermissions
    assignableScopes: environmentDeployerRoleScopes
  }
}

// resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
//   name: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor
// }

// ============================================================================================

output environmentDeployerRoleDefinitionId string = environmentDeployerRoleDefinition.id

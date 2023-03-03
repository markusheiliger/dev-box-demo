targetScope = 'subscription'

// ============================================================================================

param DeploymentPrincipalId string

// ============================================================================================

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor
}

resource contributorRoleRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, contributorRoleDefinition.id, DeploymentPrincipalId)
  scope: subscription()
  properties: {
    principalId: DeploymentPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleDefinition.id
  }
}

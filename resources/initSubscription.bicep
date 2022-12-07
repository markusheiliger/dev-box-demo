targetScope = 'subscription'

// ============================================================================================

param DevCenterIdentity string

// ============================================================================================

resource ownerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner
}

resource ownerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, ownerRoleDefinition.id, DevCenterIdentity)
  properties: {
    principalId: DevCenterIdentity
    principalType: 'ServicePrincipal'
    roleDefinitionId: ownerRoleDefinition.id
  }
}

targetScope = 'subscription'

// ============================================================================================

param DevCenterId string

// ============================================================================================

resource devCenter 'Microsoft.DevCenter/devcenters@2022-11-11-preview' existing = {
  name: string(last(split(DevCenterId, '/')))
  scope: resourceGroup(split(DevCenterId, '/')[2], split(DevCenterId, '/')[4])
}

resource ownerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner
}

resource ownerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, devCenter.id, ownerRoleDefinition.id)
  properties: {
    principalId: devCenter.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: ownerRoleDefinition.id
  }
}

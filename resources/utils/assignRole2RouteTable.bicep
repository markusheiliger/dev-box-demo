targetScope = 'resourceGroup'

// ============================================================================================

param ResourceName string

param PrincipalId string

param RoleDefinitionName string

// ============================================================================================

resource resource 'Microsoft.Network/routeTables@2022-07-01' existing = {
  name: ResourceName
}

resource roleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: RoleDefinitionName
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resource.id, roleDefinition.id, PrincipalId)
  properties: {
    principalId: PrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleDefinition.id    
  }
}

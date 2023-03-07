targetScope = 'resourceGroup'

// ============================================================================================

param ProjectName string

param ProjectUsers array

param EnvironmentName string

param EnvironmentSubscription string

param EnvironmentTags object = {}

// ============================================================================================

#disable-next-line no-loc-expr-outside-params
var ResourceLocation = resourceGroup().location

var RoleDefinitionId = {
  Contributor: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
  Reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
}

var creatorRoleAssignment = {
  roles: {
    '${RoleDefinitionId.Contributor}': {}
  }
}

var userRoleAssignments = map(ProjectUsers, usr => {
  '${usr}': {
    roles: {
      '${RoleDefinitionId.Reader}': {}
    }
  }
})

// ============================================================================================

resource project 'Microsoft.DevCenter/projects@2022-11-11-preview' existing = {
  name: ProjectName
}

resource deploymentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${ProjectName}-${EnvironmentName}'
  location: ResourceLocation
}

resource managedIdentityOperatorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'f1a07417-d97a-45cb-824c-7a7467783830' // https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#managed-identity-operator
}

resource managedIdentityOperatorRoleRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(deploymentIdentity.id, managedIdentityOperatorRoleDefinition.id, deploymentIdentity.id)
  scope: deploymentIdentity
  properties: {
    principalId: deploymentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: managedIdentityOperatorRoleDefinition.id
  }
}

resource environment 'Microsoft.DevCenter/projects/environmentTypes@2022-11-11-preview' = {
  name: EnvironmentName
  parent: project
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentIdentity.id}': {}
    }
  }
  tags: EnvironmentTags
  properties: {
    deploymentTargetId: startsWith(EnvironmentSubscription, '/') ? EnvironmentSubscription : '/subscriptions/${EnvironmentSubscription}'
    status: 'Enabled'
    creatorRoleAssignment: creatorRoleAssignment
    userRoleAssignments: reduce(userRoleAssignments, {}, (cur, next) => union(cur, next))
  }
}

// ============================================================================================

output DeploymentIdentityPrincipalId string = deploymentIdentity.properties.principalId

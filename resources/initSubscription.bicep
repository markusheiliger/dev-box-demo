targetScope = 'subscription'

// ============================================================================================

param DevCenterIdentity string

param DeploymentIdentity string

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

// resource deploymentScriptRunnerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
//   name: '04714693-d0e1-4880-9b51-ec0ab3000614'
//   properties: {
//     roleName: 'Custom Role - Deployment Script Runner'
//     description: 'Configure least privilege for the deployment principal in deployment script'
//     type: 'customRole'
//     permissions: [
//       {
//         actions: [
//           'Microsoft.Storage/storageAccounts/*'
//           'Microsoft.Storage/register/action'
//           'Microsoft.ContainerInstance/containerGroups/*'
//           'Microsoft.ContainerInstance/register/action'
//           'Microsoft.Resources/deployments/*'
//           'Microsoft.Resources/deploymentScripts/*'
//         ]
//         notActions: []
//       }
//     ]
//     assignableScopes: [
//       subscription().id
//     ]
//   }
// }

// resource deploymentScriptRunnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(subscription().id, deploymentScriptRunnerRoleDefinition.id, DeploymentIdentity)
//   properties: {
//     principalId: DeploymentIdentity
//     principalType: 'ServicePrincipal'
//     roleDefinitionId: deploymentScriptRunnerRoleDefinition.id
//   }
// }

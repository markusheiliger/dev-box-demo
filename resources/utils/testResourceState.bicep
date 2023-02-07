targetScope = 'resourceGroup'

// ============================================================================================

param ResourceId string

@allowed([ 'Canceled', 'Deleting', 'Failed', 'InProgress', 'Succeeded' ])
param ResourceState string = 'Succeeded'

param OperationId string = newGuid()

param OperationIsolated bool = false

// ============================================================================================

#disable-next-line no-loc-expr-outside-params
var ResourceLocation = resourceGroup().location

var Command= 'az resource wait --ids \'${ResourceId}\' --custom \'properties.provisioningState==`${ResourceState}`\''

// ============================================================================================

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'ResourceState'
  location: ResourceLocation
}

resource readerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
}

resource readerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, readerRoleDefinition.id, identity.id)
  properties: {
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: readerRoleDefinition.id
  }
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  #disable-next-line use-stable-resource-identifiers
  name: 'ResourceState-${guid(ResourceId, ResourceState, OperationIsolated ? OperationId : '')}'
  location: ResourceLocation
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  dependsOn: [
    readerRoleAssignment
  ]
  kind: 'AzureCLI'
  properties: {
    forceUpdateTag: OperationId
    azCliVersion: '2.40.0'
    timeout: 'PT30M'
    scriptContent: 'az config set extension.use_dynamic_install=yes_without_prompt; ${Command}'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
    // retentionInterval: 'P1D'
  }
}

// ============================================================================================

output ResourceId string = ResourceId

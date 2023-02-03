targetScope = 'resourceGroup'

// ============================================================================================

param ResourceType string

param ResourceName string

param TimeStamp string = utcNow()

// ============================================================================================

#disable-next-line no-loc-expr-outside-params
var ResourceLocation = resourceGroup().location
var ResourceId = resourceId(ResourceType, ResourceName)

// ============================================================================================

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'ExistsResource'
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
  name: 'ExistsResource-${guid(ResourceId)}'
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
    forceUpdateTag: TimeStamp
    azCliVersion: '2.40.0'
    timeout: 'PT30M'
    scriptContent: 'az config set extension.use_dynamic_install=yes_without_prompt; result=$(az resource show --ids \'${ResourceId}\' 2> /dev/null); jq -c --null-input --argjson exists $(if [ -z "$result" ]; then echo false; else echo true; fi) \'{ exists: $exists }\' > $AZ_SCRIPTS_OUTPUT_PATH'
    cleanupPreference: 'Always'
    retentionInterval: 'P1D'
  }
}

// ============================================================================================

output ResourceId string = ResourceId
output ResourceExists bool = deploymentScript.properties.outputs.exists

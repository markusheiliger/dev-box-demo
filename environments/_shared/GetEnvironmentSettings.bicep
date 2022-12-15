targetScope = 'resourceGroup'

// ============================================================================================

var EnvironmentSettingsIdSegments = split(resourceGroup().tags.EnvironmentSettingsId, '/')

// ============================================================================================

resource getEnvironmentSettings 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'GetEnvironmentSettings'
  #disable-next-line no-loc-expr-outside-params
  location: resourceGroup().location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceGroup().tags.EnvironmentDeployerId}': {}
    }
  }
  properties: {
    forceUpdateTag: guid(resourceGroup().id)
    azCliVersion: '2.40.0'
    timeout: 'PT30M'
    environmentVariables: [
      {
        name: 'Subscription'
        value: EnvironmentSettingsIdSegments[2]
      }
      {
        name: 'ConfigurationStore'
        value: last(EnvironmentSettingsIdSegments)
      }
      {
        name: 'EnvironmentType'
        value: resourceGroup().tags.EnvironmentTypeName
      }
    ]
    scriptContent: loadTextContent('GetEnvironmentSettings.sh') 
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}

// ============================================================================================

output Settings object = getEnvironmentSettings.properties.outputs

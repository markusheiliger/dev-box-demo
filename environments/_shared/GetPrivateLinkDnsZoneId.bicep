targetScope = 'resourceGroup'

// ============================================================================================

param DNSZoneName string

// ============================================================================================

var PrivateLinkResourceGroupIdSegments = split(resourceGroup().tags.PrivateLinkResourceGroupId, '/')

// ============================================================================================

resource getPrivateLinkDnsZoneId 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'GetPrivateLinkDnsZoneId-${replace(DNSZoneName, '.', '_')}'
  #disable-next-line no-loc-expr-outside-params
  location: resourceGroup().location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceGroup().tags.PrivateLinkAutomationIdentityId}': {}
    }
  }
  properties: {
    forceUpdateTag: guid(DNSZoneName)
    azCliVersion: '2.40.0'
    timeout: 'PT30M'
    environmentVariables: [
      {
        name: 'Subscription'
        value: PrivateLinkResourceGroupIdSegments[2]
      }
      {
        name: 'ResourceGroup'
        value: PrivateLinkResourceGroupIdSegments[4]
      }
      {
        name: 'DNSZoneName'
        value: DNSZoneName
      }
    ]
    scriptContent: loadTextContent('GetPrivateLinkDnsZoneId.sh') 
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}

// ============================================================================================

output DNSZoneId string = getPrivateLinkDnsZoneId.properties.outputs.DNSZoneId

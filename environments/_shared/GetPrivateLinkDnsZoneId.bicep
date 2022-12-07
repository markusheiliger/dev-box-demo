targetScope = 'resourceGroup'

// ============================================================================================

param DNSZoneName string

param OperationId string = newGuid()
param OperationLocation string = resourceGroup().location

// ============================================================================================

var PrivateLinkResourceGroupIdSegments = split(resourceGroup().tags.PrivateLinkResourceGroupId, '/')

// ============================================================================================

resource getPrivateLinkDnsZoneId 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'GetPrivateLinkDnsZoneId-${uniqueString(deployment().name)}'
  location: OperationLocation
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${resourceGroup().tags.DeploymentIdentityId}': {}
    }
  }
  properties: {
    forceUpdateTag: OperationId
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

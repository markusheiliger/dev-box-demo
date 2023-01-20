targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

param OrganizationSubNetId string

param PrivateDnsZonesResourceGroupId string

// ============================================================================================

var PrivateDnsZonesResourceGroupIdSegments = split(PrivateDnsZonesResourceGroupId, '/')

var ScriptFiles = [
  {
    name: 'initGateway.sh'
    content: loadFileAsBase64('../scripts/initGateway.sh')
  }
]

// ============================================================================================

resource scriptStorage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'script${uniqueString(resourceGroup().id)}'
  location: OrganizationDefinition.location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource scriptContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: '${scriptStorage.name}/default/scripts'
}

resource scriptStorageDnsZone 'Microsoft.Network/privateEndpoints@2022-07-01' existing = {
  name: 'privatelink.blob.${az.environment().suffixes.storage}'
  scope: resourceGroup(PrivateDnsZonesResourceGroupIdSegments[2], PrivateDnsZonesResourceGroupIdSegments[4])
}

resource scriptStoragePrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' ={
  name: 'script${uniqueString(resourceGroup().id)}'
  location: OrganizationDefinition.location
  properties: {
    subnet: {
      id: OrganizationSubNetId
    }
    privateLinkServiceConnections: [
      {
        name: scriptStorage.name
        properties: {
          privateLinkServiceId: scriptStorage.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

resource scriptStorageDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-07-01' = {
  name: scriptStorage.name
  parent: scriptStoragePrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: scriptStorageDnsZone.name
        properties: {
          privateDnsZoneId: scriptStorageDnsZone.id
        }
      }
    ]
  }
}

resource scriptStorageManager 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'script${uniqueString(resourceGroup().id)}'
  location: OrganizationDefinition.location
}

resource ownerRoleDefintion 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
}

resource ownerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(scriptStorage.id, ownerRoleDefintion.id, scriptStorageManager.id)
  properties: {
    principalId: scriptStorageManager.properties.principalId
    roleDefinitionId: ownerRoleDefintion.id
    principalType: 'ServicePrincipal'
  }
}

module uploadScript '../utils/uploadScript.bicep' = [for (ScriptFile, ScriptIndex) in ScriptFiles : {
  name: 'Upload-${guid(string(ScriptFile))}'
  params: {
    FileContent: ScriptFile.content
    FileName: ScriptFile.name
    StorageAccountName: scriptStorage.name
    StorageContainerName: last(split(scriptContainer.name, '/'))
  }
}]

resource sharedStorageLock 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'lock-${guid(scriptStorage.id)}'
  location: OrganizationDefinition.location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptStorageManager.id}': {}
    }
  }
  dependsOn: [
    uploadScript
  ]
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.42.0'
    timeout: 'PT5M'
    retentionInterval: 'PT1H'
    scriptContent: 'az storage account update --subscription ${subscription().subscriptionId} --resource-group ${resourceGroup().name} --name ${scriptStorage.name} --public-network-access Disabled'
  }
}

// ============================================================================================

output ScriptStorageAccountId string = scriptStorage.id
output ScriptStorageManagerId string = scriptStorageManager.id


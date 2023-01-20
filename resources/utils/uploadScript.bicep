targetScope = 'resourceGroup'

// ============================================================================================

param StorageAccountName string

param StorageContainerName string

param FileName string

param FileContent string

param TimeStamp string = utcNow()

// ============================================================================================

#disable-next-line no-loc-expr-outside-params
var ResourceLocation = resourceGroup().location

var ResourceSuffix = guid(join([ StorageAccountName, StorageContainerName, FileName, FileContent], '|'))

var SasTokenConfig = { 
  canonicalizedResource: '/blob/${StorageAccountName}/${StorageContainerName}'
  signedResource: 'c'
  signedProtocol: 'https'
  signedPermission: 'rwl'
  signedServices: 'b'
  signedExpiry: dateTimeAdd(TimeStamp, 'PT1H')
}

// ============================================================================================

resource storage 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: StorageAccountName
}

resource upload 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'upload-${ResourceSuffix}'
  location: ResourceLocation
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.42.0'
    timeout: 'PT5M'
    retentionInterval: 'PT1H'
    environmentVariables: [
      {
        name: 'AZURE_STORAGE_ACCOUNT'
        value: StorageAccountName
      }
      {
        name: 'AZURE_STORAGE_KEY'
        secureValue: storage.listKeys().keys[0].value
      }
      {
        name: 'CONTENT'
        value: FileContent
      }
    ]
    scriptContent: 'echo "$CONTENT" > ./base64.tmp; base64 -d ./base64.tmp > ${FileName}; az storage blob upload -f ${FileName} -c ${StorageContainerName} -n ${FileName}'
  }
}

// ============================================================================================

#disable-next-line outputs-should-not-contain-secrets
output FileUri string = '${storage.properties.primaryEndpoints.blob}${StorageContainerName}/${FileName}?${storage.listServiceSas(storage.apiVersion, SasTokenConfig).serviceSasToken}'

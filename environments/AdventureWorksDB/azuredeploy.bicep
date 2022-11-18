targetScope = 'resourceGroup'

// ============================================================================================

param DatabaseUsername string

@secure()
param DatabasePassword string

// ============================================================================================

#disable-next-line no-loc-expr-outside-params
var ResourceLocation = resourceGroup().location
var ResourcePrefix = uniqueString(resourceGroup().id)

var SampleName = 'AdventureWorksLT'

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-05-01' existing = {
  name: 'Environment'
  scope: resourceGroup(subscription().subscriptionId, 'Environment-Shared')
}

resource defaultSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' existing = {
  name : 'default'
  parent: virtualNetwork
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: '${ResourcePrefix}-SQL'
  location: ResourceLocation
  properties: {
    administratorLogin: DatabaseUsername
    administratorLoginPassword: DatabasePassword
    version: '12.0'
    publicNetworkAccess: 'Disabled'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2021-11-01' = {
  name: SampleName
  location: ResourceLocation
  parent: sqlServer
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 104857600
    sampleName: SampleName
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: '${ResourcePrefix}-SQL-PE'
  location: ResourceLocation
  properties: {
    subnet: {
      id: defaultSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: sqlServer.name
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

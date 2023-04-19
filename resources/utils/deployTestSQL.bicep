targetScope = 'resourceGroup'

// ============================================================================================

param VNetName string
param SNetName string = 'default'

param Username string = 'godfather'
param Password string = 'T00ManySecrets'

// ============================================================================================

var ResourceName = '${VNetName}-SQL'

#disable-next-line no-loc-expr-outside-params
var ResourceLocation = resourceGroup().location

// ============================================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: VNetName
}

resource snet 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' existing = {
  name: SNetName
  parent: vnet
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: ResourceName
  location: ResourceLocation
  properties: {
    administratorLogin: Username
    administratorLoginPassword: Password
    version: '12.0'
    publicNetworkAccess: 'Disabled'
  }
}

resource sqlDatabase 'Microsoft.Sql/servers/databases@2022-05-01-preview' = {
  parent: sqlServer
  name: 'AdventureWorksLT'
  location: ResourceLocation
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 104857600
    sampleName: 'AdventureWorksLT'
  }
}

module linkPrivateDnsZone 'linkPrivateDnsZone.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString(privateEndpoint.id)}'
  scope: resourceGroup('${resourceGroup().name}-PL')
  params: {
    ZoneName: 'privatelink${environment().suffixes.sqlServerHostname}'
    NetworkIds: [ vnet.id ]
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: ResourceName
  location: ResourceLocation
  properties: {
    subnet: {
      id: snet.id
    }
    privateLinkServiceConnections: [
      {
        name: guid(snet.id)
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

resource privateEndpointGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  parent: privateEndpoint
  name: ResourceName
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'default'
        properties: {
          privateDnsZoneId: linkPrivateDnsZone.outputs.ZoneId
        }
      }
    ]
  }
}

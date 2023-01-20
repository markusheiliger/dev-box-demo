targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

param OrganizationNetworkId string

param OrganizationWorkspaceId string

// ============================================================================================

var OrganizationNetworkIdSegments = split(OrganizationNetworkId, '/')

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-05-01' existing = {
  name: last(OrganizationNetworkIdSegments)
}

resource subNetwork 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' existing = {
  name: 'default'
  parent: virtualNetwork
}

resource sqlServer 'Microsoft.Sql/servers@2021-11-01' = {
  name: '${OrganizationDefinition.name}-SQL'
  location: OrganizationDefinition.location
  properties: {
    administratorLogin: 'godfather'
    administratorLoginPassword: 'T00ManySecrets'
    version: '12.0'
    publicNetworkAccess: 'Disabled'
  }
}

resource sqlDatabaseAdventureWorksLT 'Microsoft.Sql/servers/databases@2021-11-01' = {
  name: 'AdventureWorksLT'
  location: OrganizationDefinition.location
  parent: sqlServer
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

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: '${OrganizationDefinition.name}-SQL-PE'
  location: OrganizationDefinition.location
  properties: {
    subnet: {
      id: subNetwork.id
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


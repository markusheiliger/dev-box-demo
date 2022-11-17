targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

param OrganizationNetworkId string

param OrganizationWorkspaceId string

// ============================================================================================

var OrganizationNetworkIdSegments = split(OrganizationNetworkId, '/')

// ============================================================================================

module createSubnet 'createSubnet.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('createSubnet', 'SharedServicesSubnet')}'
  scope: resourceGroup(OrganizationNetworkIdSegments[2], OrganizationNetworkIdSegments[4])
  params: {
    VirtualNetworkName: last(OrganizationNetworkIdSegments)
    SubnetName: 'SharedServicesSubnet'
    SubnetProperties: {
      addressPrefix: '10.0.0.0/27'
      privateEndpointNetworkPolicies: 'Disabled'
    }
  }
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
      id: createSubnet.outputs.SubnetId
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

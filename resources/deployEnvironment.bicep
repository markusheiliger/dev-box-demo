targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

@description('The project defintion to process')
#disable-next-line no-unused-params
param ProjectDefinition object

@description('The environment definition to process')
#disable-next-line no-unused-params
param ProjectSettings object

@description('The environment settings to process')
param EnvironmentSettings object

// ============================================================================================

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'Environment'
  location: OrganizationDefinition.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        EnvironmentSettings.ipRange
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: EnvironmentSettings.ipRange
        }
      }
    ]
  }
}

// ============================================================================================

output EnvironmentNetworkId string = virtualNetwork.id

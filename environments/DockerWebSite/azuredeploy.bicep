targetScope = 'resourceGroup'

// ============================================================================================

param DockerImage string = 'mcr.microsoft.com/appsvc/staticsite:latest'

// ============================================================================================

#disable-next-line no-loc-expr-outside-params
var ResourceLocation = resourceGroup().location
var ResourcePrefix = uniqueString(resourceGroup().id)

var EnvironmentNetworkIdSegments = split(resourceGroup().tags.EnvironmentNetworkId, '/')

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-05-01' existing = {
  name: last(EnvironmentNetworkIdSegments)
  scope: resourceGroup(EnvironmentNetworkIdSegments[2], EnvironmentNetworkIdSegments[4])
}


resource defaultSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' existing = {
  name : 'default'
  parent: virtualNetwork
}

resource webServer 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: '${ResourcePrefix}-SRV'
  location: ResourceLocation
  kind: 'linux'
  properties: {
    reserved: true
  }	
  sku:  {
  	name: 'B1'
    tier: 'Basic'
  }
}

resource webSite 'Microsoft.Web/sites@2022-03-01' = {
  name: '${ResourcePrefix}-APP'
  location: ResourceLocation
  properties: {
    serverFarmId: webServer.id
    siteConfig: {
      appSettings: []
      linuxFxVersion: 'DOCKER|${DockerImage}'
    }
  }
}


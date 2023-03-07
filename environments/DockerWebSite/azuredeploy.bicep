targetScope = 'resourceGroup'

// ============================================================================================

param DockerImage string = 'mcr.microsoft.com/appsvc/staticsite:latest'

// ============================================================================================

#disable-next-line no-loc-expr-outside-params
var ResourceLocation = resourceGroup().location
var ResourcePrefix = uniqueString(resourceGroup().id)

// ============================================================================================

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


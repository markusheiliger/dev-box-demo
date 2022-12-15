targetScope = 'resourceGroup'

// ============================================================================================


// ============================================================================================

#disable-next-line no-loc-expr-outside-params
var ResourceLocation = resourceGroup().location
var ResourcePrefix = uniqueString(resourceGroup().id)


// ============================================================================================

module EnvironmentSettings '../_shared/GetEnvironmentSettings.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('EnvironmentSettings')}'
}

// ============================================================================================

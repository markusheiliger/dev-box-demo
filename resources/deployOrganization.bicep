targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationJson object

// ============================================================================================

var DevBoxes = contains(OrganizationJson, 'devboxes') ? OrganizationJson.devboxes : []
var EnvTypes = contains(OrganizationJson, 'environments') ? OrganizationJson.environments : []
var Catalogs = contains(OrganizationJson, 'catalogs') ? OrganizationJson.catalogs : []

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: OrganizationJson.name
  location: OrganizationJson.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/24'
      ]
    }
  }
}

resource resourceSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  parent: virtualNetwork
  name: 'ResourceSubnet'
  properties: {
    addressPrefix: '10.0.0.0/27'
    privateEndpointNetworkPolicies: 'Disabled'
  }
} 

resource factorySubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  parent: virtualNetwork
  name: 'FactorySubnet'
  properties: {
    addressPrefix: '10.0.0.32/27'
    privateLinkServiceNetworkPolicies: 'Disabled'
  }
  dependsOn: [
    resourceSubnet // enforce sequential provisioning to avoid conflicts
  ]
} 

resource azureBastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  parent: virtualNetwork
  name: 'AzureBastionSubnet'
  properties: {
    addressPrefix: '10.0.0.64/27'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Disabled'
  }
  dependsOn: [
    factorySubnet // enforce sequential provisioning to avoid conflicts
  ]
} 

resource gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  parent: virtualNetwork
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: '10.0.0.96/27'
  }
  dependsOn: [
    azureBastionSubnet // enforce sequential provisioning to avoid conflicts
  ]
} 

resource azureFirewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = {
  parent: virtualNetwork
  name: 'AzureFirewallSubnet'
  properties: {
    addressPrefix: '10.0.0.128/26'
  }
  dependsOn: [
    gatewaySubnet // enforce sequential provisioning to avoid conflicts
  ]
} 

resource devCenter 'Microsoft.DevCenter/devcenters@2022-08-01-preview' = {
  name: OrganizationJson.name
  location: OrganizationJson.location
  identity: {
    type: 'SystemAssigned'
  }
}

resource devBox 'Microsoft.DevCenter/devcenters/devboxdefinitions@2022-08-01-preview' = [for DevBox in DevBoxes: {
  name: DevBox.name
  location: OrganizationJson.location
  parent: devCenter
  properties: {
    imageReference: {
      id: resourceId('Microsoft.DevCenter/devcenters/galleries/images', devCenter.name, 'default', DevBox.image)
    }
    sku: {
      name: DevBox.sku
    }
    osStorageType: DevBox.storage
  }
}]

resource envType 'Microsoft.DevCenter/devcenters/environmentTypes@2022-09-01-preview' = [for EnvType in EnvTypes: {
  name: EnvType
  parent: devCenter
}]

resource gallery 'Microsoft.Compute/galleries@2021-10-01' = {
  name: OrganizationJson.name
  location: OrganizationJson.location
}

resource vault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: OrganizationJson.name
  location: OrganizationJson.location
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    sku: {
      name: 'standard'
      family: 'A'
    }
    createMode: 'default'
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    // enablePurgeProtection: false
    // enableSoftDelete: false
  }
}

resource vaultSecretUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource vaultSecretUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(devCenter.id)
  scope: vault
  properties: {
    principalType: 'ServicePrincipal'
    principalId: devCenter.identity.principalId
    roleDefinitionId: vaultSecretUserRoleDefinition.id
  }
}

resource vaultSecret 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = [for (Catalog, CatalogIndex) in Catalogs : {
  name: Catalog.name
  parent: vault
  properties: {
    value: Catalog.secret
  }
}]

resource catalogGitHub 'Microsoft.DevCenter/devcenters/catalogs@2022-09-01-preview' = [for (Catalog, CatalogIndex) in Catalogs : if (Catalog.type == 'gitHub') {
  name: '${Catalog.name}'
  parent: devCenter
  properties: {
    gitHub: {
      uri: Catalog.uri
      branch: Catalog.branch
      secretIdentifier: vaultSecret[CatalogIndex].properties.secretUri
      path: Catalog.path
    }
  }
}]

resource catalogAdoGit 'Microsoft.DevCenter/devcenters/catalogs@2022-09-01-preview' = [for (Catalog, CatalogIndex) in Catalogs : if (Catalog.type == 'adoGit') {
  name: '${Catalog.name}'
  parent: devCenter
  properties: {
    adoGit: {
      uri: Catalog.uri
      branch: Catalog.branch
      secretIdentifier: vaultSecret[CatalogIndex].properties.secretUri
      path: Catalog.path
    }
  }
}]

output OrganizationNetworkId string = virtualNetwork.id
output OrganizationDevCenterId string = devCenter.id
output OrganizationDevCenterIdentity string = devCenter.identity.principalId
output OrganizationGalleryId string = gallery.id

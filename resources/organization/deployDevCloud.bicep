targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

@description('The Windows 365 principal id')
param Windows365PrinicalId string

param WorkspaceId string = ''

// ============================================================================================

var DevBoxes = contains(OrganizationDefinition, 'devboxes') ? OrganizationDefinition.devboxes : []
var EnvTypes = contains(OrganizationDefinition, 'environments') ? OrganizationDefinition.environments : []
var Catalogs = contains(OrganizationDefinition, 'catalogs') ? OrganizationDefinition.catalogs : []
var CatalogsGitHub = filter(Catalogs, Catalog => Catalog.type == 'gitHub')
var CatalogsAdoGit = filter(Catalogs, Catalog => Catalog.type == 'adoGit')

// ============================================================================================

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor
}

resource readerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7' // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#reader
}

resource devCenter 'Microsoft.DevCenter/devcenters@2022-10-12-preview' = {
  name: OrganizationDefinition.name
  location: OrganizationDefinition.location
  identity: {
    type:'SystemAssigned'
  }
}

resource devCenterDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(WorkspaceId)) {
  name: devCenter.name
  scope: devCenter
  properties: {
    workspaceId: WorkspaceId
    logs: [
      {
        categoryGroup: 'audit'
        enabled: true
        retentionPolicy: {
          days: 7
          enabled: true
        }
      }
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          days: 7
          enabled: true
        }
      }
    ]
    metrics: []
  }
}

resource devBox 'Microsoft.DevCenter/devcenters/devboxdefinitions@2022-10-12-preview' = [for DevBox in DevBoxes: {
  name: DevBox.name
  location: OrganizationDefinition.location
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
  name: OrganizationDefinition.name
  location: OrganizationDefinition.location
}

resource galleryContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(gallery.id, contributorRoleDefinition.id, devCenter.id)
  scope: gallery
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: devCenter.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource galleryReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(gallery.id, readerRoleDefinition.id, Windows365PrinicalId)
  scope: gallery
  properties: {
    roleDefinitionId: readerRoleDefinition.id
    principalId: Windows365PrinicalId
    principalType: 'ServicePrincipal'
  }
}

resource attachGallery 'Microsoft.DevCenter/devcenters/galleries@2022-10-12-preview' = {
  name: gallery.name
  parent: devCenter
  dependsOn: [
    galleryContributorRoleAssignment
    galleryReaderRoleAssignment
  ]
  properties: {
    #disable-next-line use-resource-id-functions
    galleryResourceId: gallery.id
  }
}

resource vault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: any(OrganizationDefinition.name)
  location: OrganizationDefinition.location
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
  }
}

resource vaultSecretUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource vaultSecretUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vault.id, vaultSecretUserRoleDefinition.id, devCenter.id)
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

resource catalogGitHub 'Microsoft.DevCenter/devcenters/catalogs@2022-10-12-preview' = [for (Catalog, CatalogIndex) in CatalogsGitHub : {
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

resource catalogAdoGit 'Microsoft.DevCenter/devcenters/catalogs@2022-10-12-preview' = [for (Catalog, CatalogIndex) in CatalogsAdoGit : {
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

// ============================================================================================

output DevCenterId string = devCenter.id

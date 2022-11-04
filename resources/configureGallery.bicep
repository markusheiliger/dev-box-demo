targetScope = 'resourceGroup'

// ============================================================================================

@description('The gallery id')
param GalleryId string

@description('Identities that should become gallery owner')
param GalleryOwnerIdentities array = [
  // empty by default
]

@description('Identities that should become gallery contributor')
param GalleryContributorIdentities array = [
  // empty by default
]

@description('Identities that should become gallery reader')
param GalleryReaderIdentities array = [
  // empty by default
]

// ============================================================================================

resource gallery 'Microsoft.Compute/galleries@2021-10-01' existing = {
  name: last(split(GalleryId, '/'))
}

resource ownerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: resourceGroup()
  name: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner
}

resource ownerRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for identity in GalleryOwnerIdentities: {
  name: guid(gallery.id, ownerRoleDefinition.name, identity)
  scope: gallery
  properties: {
    roleDefinitionId: ownerRoleDefinition.id
    principalId: identity
  }
}]

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: resourceGroup()
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor
}

resource ontributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for identity in GalleryContributorIdentities: {
  name: guid(gallery.id, contributorRoleDefinition.name, identity)
  scope: gallery
  properties: {
    roleDefinitionId: contributorRoleDefinition.id
    principalId: identity
  }
}]

resource readerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
  scope: resourceGroup()
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7' // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#reader
}

resource readerRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for identity in GalleryReaderIdentities: {
  name: guid(gallery.id, readerRoleDefinition.name, identity)
  scope: gallery
  properties: {
    roleDefinitionId: readerRoleDefinition.id
    principalId: identity
  }
}]

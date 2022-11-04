targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization DevCenter Id')
param OrganizationDevCenterId string

@description('The organization gallery id')
param OrganizationGalleryId string

@description('The project network connection id')
param ProjectNetworkConnectionId string

// ============================================================================================

resource devCenter 'Microsoft.DevCenter/devcenters@2022-08-01-preview' existing = {
  name: last(split(OrganizationDevCenterId, '/'))
}

resource galleryAttach 'Microsoft.DevCenter/devcenters/galleries@2022-08-01-preview' = {
  name: last(split(OrganizationGalleryId, '/'))
  parent: devCenter
  properties: {
    #disable-next-line use-resource-id-functions
    galleryResourceId: OrganizationGalleryId
  }
}

resource networkAttach 'Microsoft.DevCenter/devcenters/attachednetworks@2022-08-01-preview' = {
  name: '${last(split(ProjectNetworkConnectionId, '/'))}'
  parent: devCenter
  properties: {
    networkConnectionId: ProjectNetworkConnectionId
  }
}

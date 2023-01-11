targetScope = 'resourceGroup'

// ============================================================================================

param DevCenterName string

param GalleryId string

// ============================================================================================

resource devCenter 'Microsoft.DevCenter/devcenters@2022-10-12-preview' existing = {
  name: DevCenterName
}

resource attachGallery 'Microsoft.DevCenter/devcenters/galleries@2022-10-12-preview' = {
  name: last(split(GalleryId, '/'))
  parent: devCenter
  properties: {
    #disable-next-line use-resource-id-functions
    galleryResourceId: GalleryId
  }
}

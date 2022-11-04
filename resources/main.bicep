targetScope = 'subscription'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationJson object

@description('The project defintion to process')
param ProjectJson object

@description('The Windows 365 principal id')
param Windows365PrinicalId string

// ============================================================================================

resource organizationResourceGroup 'Microsoft.Resources/resourceGroups@2019-10-01' = {
  name: 'ORG-${OrganizationJson.name}'
  location: OrganizationJson.location
  properties: {}
}

module deployOrganization 'deployOrganization.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString(OrganizationJson.name)}'
  scope: organizationResourceGroup
  params:{
    OrganizationJson: OrganizationJson
  }
}

resource projectResourceGroup 'Microsoft.Resources/resourceGroups@2019-10-01' = {
  name: 'PRJ-${OrganizationJson.name}-${ProjectJson.name}'
  location: OrganizationJson.location
  properties: {}
}

module deployProject 'deployProject.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployProject', ProjectJson.name)}'
  scope: projectResourceGroup
  params:{
    OrganizationJson: OrganizationJson
    OrganizationDevCenterId: deployOrganization.outputs.OrganizationDevCenterId
    ProjectJson: ProjectJson
  }
}

module peerNetworks 'peerNetworks.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('peerNetwork')}'
  scope: subscription()
  params: {
    HubNetworkId: deployOrganization.outputs.OrganizationNetworkId
    SpokeNetworkId: deployProject.outputs.ProjectNetworkId
  }
}

module configureOrganizationGallery 'configureGallery.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('configureGallery', 'organization', OrganizationJson.name)}'
  scope: organizationResourceGroup
  params: {
    GalleryId: deployOrganization.outputs.OrganizationGalleryId
    GalleryReaderIdentities: [
      Windows365PrinicalId
      deployOrganization.outputs.OrganizationDevCenterIdentity
    ]
  }
}

module configureDevCenter 'configureDevCenter.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('configureDevCenter', OrganizationJson.name)}'
  scope: organizationResourceGroup
  dependsOn: [
    configureOrganizationGallery
  ]
  params: {
    OrganizationDevCenterId: deployOrganization.outputs.OrganizationDevCenterId
    OrganizationGalleryId: deployOrganization.outputs.OrganizationGalleryId
    ProjectNetworkConnectionId: deployProject.outputs.ProjectNetworkConnectionId
  }
}

module configureProject 'configureProject.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('configureProject', OrganizationJson.name)}'
  scope: projectResourceGroup
  dependsOn: [
    deployProject
    configureDevCenter
  ]
  params:{
    OrganizationJson: OrganizationJson
    ProjectJson: ProjectJson
  }
}

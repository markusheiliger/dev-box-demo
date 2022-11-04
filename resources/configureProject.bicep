targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationJson object

@description('The project defintion to process')
param ProjectJson object

// ============================================================================================

var DevBoxes = contains(OrganizationJson, 'devboxes') ? OrganizationJson.devboxes : []

// ============================================================================================

resource project 'Microsoft.DevCenter/projects@2022-09-01-preview' existing = {
  name: ProjectJson.name
}

resource networkConnection 'Microsoft.DevCenter/devcenters@2022-09-01-preview' existing = {
  name: ProjectJson.name
}

resource devBoxPool 'Microsoft.DevCenter/projects/pools@2022-09-01-preview' = [for DevBox in DevBoxes: {
  parent: project
  name: '${DevBox.name}Pool'
  location: OrganizationJson.Location
  properties: {
    devBoxDefinitionName: DevBox.name
    networkConnectionName: networkConnection.name
    licenseType: 'Windows_Client'
    localAdministrator: 'Enabled'
  }
}]

targetScope = 'subscription'

// ============================================================================================

param OrganizationDefinition object
param ProjectDefinitions array
param Windows365PrinicalId string

// ============================================================================================

var DeploymentContext = {
  Windows365PrinicalId: Windows365PrinicalId
  Features: {
    TestHost: false
  } 
}

// ============================================================================================

module organization './organization.bicep' = {
  name: '${take(deployment().name, 36)}_organization'
  params: {
    OrganizationDefinition: OrganizationDefinition
    ProjectDefinitions: ProjectDefinitions
    DeploymentContext: DeploymentContext
  }
}

// ============================================================================================



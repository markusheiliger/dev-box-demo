targetScope = 'subscription'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

@description('The project defintion to process')
param ProjectDefinitions array

@description('The Windows 365 principal id')
param Windows365PrinicalId string

// ============================================================================================

var Environments = flatten(map(range(0, length(ProjectDefinitions)), i => map(ProjectDefinitions[i].environments, env => {
  projectIndex: i
  environment: env
})))

var Features = {
  TestHost: true
} 

// ============================================================================================

module mainOrganization 'mainOrganization.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString(string(OrganizationDefinition))}'
  params: {
    OrganizationDefinition: OrganizationDefinition
    Windows365PrinicalId: Windows365PrinicalId
    Features: Features
  }
}

@batchSize(1)
module mainProject 'mainProject.bicep' = [for ProjectDefinition in ProjectDefinitions: {
  name: '${take(deployment().name, 36)}_${uniqueString(string(ProjectDefinition))}'
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationInfo: mainOrganization.outputs.OrganizationInfo
    ProjectDefinition: ProjectDefinition
    Features: Features
  }
}]

module deployEnvironment 'mainEnvironment.bicep' = [for e in Environments: {
  name: '${take(deployment().name, 36)}_${uniqueString(string(ProjectDefinitions[e.projectIndex]), string(e.environment))}'
  scope: subscription(e.environment.subscription)
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationInfo: mainOrganization.outputs.OrganizationInfo
    ProjectDefinition: ProjectDefinitions[e.projectIndex]
    ProjectInfo: mainProject[e.projectIndex].outputs.ProjectInfo
    EnvironmentDefinition: e.environment
    Features: Features
  }
}]

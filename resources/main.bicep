targetScope = 'subscription'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

@description('The project defintion to process')
param ProjectDefinition object

@description('The Windows 365 principal id')
param Windows365PrinicalId string

// ============================================================================================

var Features = {
  TestHost: true
} 

// ============================================================================================

module mainOrganization 'mainOrganization.bicep' = {
  name: '${take(deployment().name, 36)}_mainOrganization'
  params: {
    OrganizationDefinition: OrganizationDefinition
    Windows365PrinicalId: Windows365PrinicalId
    Features: Features
  }
}

module mainProject 'mainProject.bicep' = {
  name: '${take(deployment().name, 36)}_mainProject'
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationInfo: mainOrganization.outputs.OrganizationInfo
    ProjectDefinition: ProjectDefinition
    Features: Features
  }
}

module deployEnvironment 'mainEnvironment.bicep' = [for EnvironmentDefinition in ProjectDefinition.environments: {
  name: '${take(deployment().name, 36)}_mainEnvironment_${EnvironmentDefinition.name}'
  scope: subscription(EnvironmentDefinition.subscription)
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationInfo: mainOrganization.outputs.OrganizationInfo
    ProjectDefinition: ProjectDefinition
    ProjectInfo: mainProject.outputs.ProjectInfo
    EnvironmentDefinition: EnvironmentDefinition
    Features: Features
  }
}]

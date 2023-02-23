targetScope = 'subscription'

// ============================================================================================

param OrganizationDefinition object
param OrganizationContext object
param ProjectDefinition object
param ProjectContext object
param DeploymentContext object

// ============================================================================================

module environment './environment.bicep' = [for EnvironmentDefinition in ProjectDefinition.environments: {
  name: '${take(deployment().name, 36)}_env-${uniqueString(string(ProjectDefinition), string(EnvironmentDefinition))}'
  scope: subscription(EnvironmentDefinition.subscription)
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationContext: OrganizationContext
    ProjectDefinition: ProjectDefinition
    ProjectContext: ProjectContext
    EnvironmentDefinition: EnvironmentDefinition
    DeploymentContext: DeploymentContext
  }
}]

// ============================================================================================

output EnvironmentResults array = [ for i in range(0, length(ProjectDefinition.environments)) : environment[i].outputs.EnvironmentResult ]

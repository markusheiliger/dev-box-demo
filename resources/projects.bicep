targetScope = 'subscription'

// ============================================================================================

param OrganizationDefinition object
param OrganizationContext object
param ProjectDefinitions array
param DeploymentContext object

// ============================================================================================

module project './project.bicep' = [for (ProjectDefinition, ProjectIndex) in ProjectDefinitions: {
  name: '${take(deployment().name, 36)}_prj-${uniqueString(string(OrganizationDefinition), string(ProjectDefinition))}'
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationContext: OrganizationContext
    ProjectDefinition: ProjectDefinition
    DeploymentContext: DeploymentContext
  }
}]

// ============================================================================================

output ProjectResults array = [ for i in range(0, length(ProjectDefinitions)): project[i].outputs.ProjectResult ]

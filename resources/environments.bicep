targetScope = 'subscription'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

param OrganizationInfo object

@description('The project defintion to process')
param ProjectDefinition object

param ProjectInfo object

param Features object

// ============================================================================================

module deployCoreEnvironmentSubscription 'core/deployCore-EnvironmentSubscription.bicep' = [for EnvironmentDefinition in ProjectDefinition.environments: {
  name: '${take(deployment().name, 36)}_${uniqueString('deployCoreEnvironmentSubscription', EnvironmentDefinition.name)}'
  scope: subscription(EnvironmentDefinition.subscription)
  params: {
    EnvironmentDefinition: EnvironmentDefinition
    OrganizationDefinition: OrganizationDefinition
    OrganizationInfo: OrganizationInfo
    ProjectDefinition: ProjectDefinition
    ProjectInfo: ProjectInfo
    Features: Features
  }
}]

// ============================================================================================

output NetworkIds array = [for i in range(0, length(ProjectDefinition.environments)): deployCoreEnvironmentSubscription[i].outputs.NetworkId]
output DefaultSubNetIds array = [for i in range(0, length(ProjectDefinition.environments)): deployCoreEnvironmentSubscription[i].outputs.DefaultSubNetId]

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

module deployEnvironmentSubscription 'core/resources/deployEnvironmentSubscription.bicep' = [for EnvironmentDefinition in ProjectDefinition.environments: {
  name: '${take(deployment().name, 36)}_${uniqueString('deployEnvironmentSubscription', EnvironmentDefinition.name)}'
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

output VNetIds array = [for (EnvDef, EnvIndex) in ProjectDefinition.environments: deployEnvironmentSubscription[EnvIndex].outputs.VNetId]
output DefaultSNetIds array = [for (EnvDef, EnvIndex) in ProjectDefinition.environments: deployEnvironmentSubscription[EnvIndex].outputs.DefaultSNetId]

output EnvironmentInfos array = [for (EnvDef, EnvIndex) in ProjectDefinition.environments: {
  Environment: EnvDef
  IpRanges: deployEnvironmentSubscription[EnvIndex].outputs.IpRanges
}]

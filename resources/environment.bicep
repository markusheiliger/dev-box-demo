targetScope = 'subscription'

// ============================================================================================

param OrganizationDefinition object
param OrganizationContext object
param ProjectDefinition object
param ProjectContext object
param EnvironmentDefinition object
param DeploymentContext object

// ============================================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'ENV-${OrganizationDefinition.name}-${ProjectDefinition.name}-${EnvironmentDefinition.name}'
  location: OrganizationDefinition.location
}

module networkExists 'utils/testResourceExists.bicep' = {
  name: '${take(deployment().name, 36)}_networkExists'
  scope: resourceGroup
  params: {
    ResourceName: EnvironmentDefinition.name
    ResourceType: 'Microsoft.Network/virtualNetworks'
  }
}

module deployNetwork './environment/deployNetwork.bicep' = {
  name: '${take(deployment().name, 36)}_deployNetwork'
  scope: resourceGroup
  params: {
    OrganizationDefinition: OrganizationDefinition
    ProjectDefinition: ProjectDefinition
    ProjectGatewayIP: ProjectContext.GatewayIP
    ProjectNetworkId: ProjectContext.NetworkId
    EnvironmentDefinition: EnvironmentDefinition
    InitialDeployment: !networkExists.outputs.ResourceExists
  }
}

module deployTestHost 'utils/deployTestHost.bicep' = if (DeploymentContext.Features.TestHost) {
  name: '${take(deployment().name, 36)}_deployTestHost'
  scope: resourceGroup
  params: {
    VNetName: deployNetwork.outputs.VNetName
  }
}

// ============================================================================================

output EnvironmentResult object = {
  NetworkId: deployNetwork.outputs.VNetId
}

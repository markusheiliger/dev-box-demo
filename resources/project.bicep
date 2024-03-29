targetScope = 'subscription'

// ============================================================================================

param OrganizationDefinition object
param OrganizationContext object
param ProjectDefinition object
param DeploymentContext object

// ============================================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'PRJ-${ProjectDefinition.name}'
  location: OrganizationDefinition.location
}

module networkExists 'utils/testResourceExists.bicep' = {
  name: '${take(deployment().name, 36)}_networkExists'
  scope: resourceGroup
  params: {
    ResourceName: ProjectDefinition.name
    ResourceType: 'Microsoft.Network/virtualNetworks'
  }
}

module deployNetwork 'project/deployNetwork.bicep' = {
  name: '${take(deployment().name, 36)}_deployNetwork'
  scope: resourceGroup
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationGatewayIP: OrganizationContext.GatewayIP
    OrganizationNetworkId: OrganizationContext.NetworkId
    ProjectDefinition: ProjectDefinition
    InitialDeployment: !networkExists.outputs.ResourceExists
  }
}

module deployGateway 'project/deployGateway.bicep' = {
  name: '${take(deployment().name, 36)}_deployGateway'
  scope: resourceGroup
  dependsOn: [
    deployNetwork
  ]
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationGatewayIP: OrganizationContext.GatewayIP
    ProjectDefinition: ProjectDefinition
  }
}

module deployTestHost 'utils/deployTestHost.bicep' = if (DeploymentContext.Features.TestHost) {
  name: '${take(deployment().name, 36)}_deployTestHost'
  scope: resourceGroup
  dependsOn: [
    // deployForwarder
    deployGateway
  ]
  params: {
    VNetName: deployNetwork.outputs.VNetName
  }
}

// ============================================================================================
//
// DEPLOY ENVIRONMENTS
//
// ============================================================================================

module environments './environments.bicep' = {
  name: '${take(deployment().name, 36)}_envs-${uniqueString(string(ProjectDefinition))}'
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationContext: OrganizationContext
    ProjectDefinition: ProjectDefinition
    ProjectContext:{
      NetworkId: deployNetwork.outputs.VNetId
      GatewayIP: deployGateway.outputs.GatewayIP
    }
    DeploymentContext: DeploymentContext
  }
}

module peerNetworks 'utils/peerNetworks.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString(deployment().name)}'
  params: {
    HubNetworkId: deployNetwork.outputs.VNetId
    HubPeeringPrefix: 'project'
    HubGatewayIP: deployGateway.outputs.GatewayIP
    SpokeNetworkIds: map(environments.outputs.EnvironmentResults, ctx => ctx.NetworkId)
    SpokePeeringPrefix: 'environment'
  }
}

// ============================================================================================

output ProjectResult object = {
  ResourceGroupId: resourceGroup.id
  NetworkId: deployNetwork.outputs.VNetId
  GatewayIP: deployGateway.outputs.GatewayIP
  EnvironmentResults: environments.outputs.EnvironmentResults
}

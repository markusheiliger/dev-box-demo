targetScope = 'subscription'

// ============================================================================================

param OrganizationDefinition object
param ProjectDefinitions array
param DeploymentContext object

// ============================================================================================

var EnvironmentSubscriptions = union([],flatten(map(ProjectDefinitions, prj => map(prj.environments, env => env.subscription))))

// ============================================================================================
//
// DEPLOY ORGANIZATION
//
// ============================================================================================

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'ORG-${OrganizationDefinition.name}'
  location: OrganizationDefinition.location
}

module deployMonitoring './organization/deployMonitoring.bicep' = {
  name: '${take(deployment().name, 36)}_deployMonitoring'
  scope: resourceGroup
  params: {
    OrganizationDefinition: OrganizationDefinition
  }
}

module networkExists 'utils/testResourceExists.bicep' = {
  name: '${take(deployment().name, 36)}_networkExists'
  scope: resourceGroup
  params: {
    ResourceName: OrganizationDefinition.name
    ResourceType: 'Microsoft.Network/virtualNetworks'
  }
}

module deployNetwork './organization/deployNetwork.bicep' = {
  name: '${take(deployment().name, 36)}_deployNetwork'
  scope: resourceGroup
  params: {
    OrganizationDefinition: OrganizationDefinition
    InitialDeployment: !networkExists.outputs.ResourceExists
  }
}

module deployBastion 'organization/deployBastion.bicep' = {
  name: '${take(deployment().name, 36)}_deployBastion'
  scope: resourceGroup
  dependsOn: [
    deployNetwork
  ]
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationWorkspaceId:  deployMonitoring.outputs.WorkspaceId
  }
}

module gatewayExists 'utils/testResourceExists.bicep' = {
  name: '${take(deployment().name, 36)}_gatewayExists'
  scope: resourceGroup
  params: {
    ResourceName: '${OrganizationDefinition.name}-FW'
    ResourceType: 'Microsoft.Network/azureFirewalls'
  }
}

module deployGateway 'organization/deployGateway.bicep' = {
  name: '${take(deployment().name, 36)}_deployGateway'
  scope: resourceGroup
  dependsOn: [
    deployNetwork
  ]
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationWorkspaceId:  deployMonitoring.outputs.WorkspaceId
    InitialDeployment: !gatewayExists.outputs.ResourceExists
  }
}

module deployTestHost 'utils/deployTestHost.bicep' = if (DeploymentContext.Features.TestHost) {
  name: '${take(deployment().name, 36)}_deployTestHost'
  scope: resourceGroup
  params: {
    SNetName: deployNetwork.outputs.DefaultSNetName
    VNetName: deployNetwork.outputs.VNetName
  }
}

// ============================================================================================
//
// DEPLOY PROJECTS
//
// ============================================================================================

module projects './projects.bicep' = {
  name: '${take(deployment().name, 36)}_projects'
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationContext: {
      GatewayIP: deployGateway.outputs.GatewayIP
      NetworkId: deployNetwork.outputs.VNetId
      WorkspaceId: deployMonitoring.outputs.WorkspaceId
    }
    ProjectDefinitions: ProjectDefinitions
    DeploymentContext: DeploymentContext
  }
}

module peerNetworks 'utils/peerNetworks.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString(deployment().name)}'
  params: {
    HubNetworkId: deployNetwork.outputs.VNetId
    SpokeNetworkIds: map(projects.outputs.ProjectResults, ctx => ctx.NetworkId)
    UpdateIPGroups: true
  }
}

// ============================================================================================
//
// DEPLOY PROJECTS
//
// ============================================================================================

module deployDevCenter 'organization/deployDevCloud.bicep'= {
  name: '${take(deployment().name, 36)}_deployDevCloud'
  scope: resourceGroup
  dependsOn: [
    peerNetworks
  ]
  params: {
    OrganizationDefinition: OrganizationDefinition
    Windows365PrinicalId: DeploymentContext.Windows365PrinicalId
    WorkspaceId: deployMonitoring.outputs.WorkspaceId
  }
}

module attachEnvironmentSubscription './utils/attachEnvironmentSubscription.bicep' = [for EnvironmentSubscription in EnvironmentSubscriptions: {
  name: '${take(deployment().name, 36)}_${uniqueString('attachEnvironmentSubscription', EnvironmentSubscription)}'
  scope: subscription(EnvironmentSubscription)
  params: {
    DevCenterId: deployDevCenter.outputs.DevCenterId
  }  
}]

module deployDevProject 'project/deployDevCloud.bicep' = [for ProjectDefinition in ProjectDefinitions: {
  name:'${take(deployment().name, 36)}_deployDevCloud'
  scope: az.resourceGroup('PRJ-${ProjectDefinition.name}')
  params: {
    DevCenterId: deployDevCenter.outputs.DevCenterId
    OrganizationDefinition: OrganizationDefinition
    ProjectDefinition: ProjectDefinition
  }
}]

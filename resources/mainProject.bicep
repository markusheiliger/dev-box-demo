targetScope = 'subscription'

// ============================================================================================

param OrganizationDefinition object

param OrganizationInfo object

param ProjectDefinition object

param Features object

// ============================================================================================

resource projectResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'PRJ-${ProjectDefinition.name}'
  location: OrganizationDefinition.location
}

module testResourceExists 'utils/testResourceExists.bicep' = {
  name: '${take(deployment().name, 36)}_existsVirtualNetwork'
  scope: projectResourceGroup
  params: {
    ResourceName: ProjectDefinition.name
    ResourceType: 'Microsoft.Network/virtualNetworks'
  }
}

module deployResources 'project/deployResources.bicep' = {
  name: '${take(deployment().name, 36)}_deployResources'
  scope: projectResourceGroup
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationInfo: OrganizationInfo
    ProjectDefinition: ProjectDefinition
    InitialDeployment: !testResourceExists.outputs.ResourceExists
  }
}

module deployGateway 'project/deployGateway.bicep' = {
  name: '${take(deployment().name, 36)}_deployGateway'
  scope: projectResourceGroup
  dependsOn: [
    deployResources
  ]
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationInfo: OrganizationInfo
    ProjectDefinition: ProjectDefinition
  }
}

module deployDevCloud 'project/deployDevCloud.bicep' = {
  name: '${take(deployment().name, 36)}_deployDevCloud'
  scope: projectResourceGroup
  dependsOn: [
    deployGateway
  ]
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationInfo: OrganizationInfo
    ProjectDefinition: ProjectDefinition
  }
}

module deployTestHost 'utils/deployTestHost.bicep' = if (Features.TestHost) {
  name: '${take(deployment().name, 36)}_deployTestHost'
  scope: projectResourceGroup
  dependsOn: [
    deployGateway
  ]
  params: {
    SNetName: deployResources.outputs.DefaultSNetName
    VNetName: deployResources.outputs.VNetName
  }
}

// ============================================================================================

output ProjectInfo object = {
  SubscriptionId: subscription().subscriptionId
  ResourceGroupId: projectResourceGroup.id
  ResourceGroupName: projectResourceGroup.name
  NetworkId: deployResources.outputs.VNetId
  DefaultSubNetId: deployResources.outputs.DefaultSNetId
  DnsZoneId: deployResources.outputs.DnsZoneId
  ProjectId: deployDevCloud.outputs.ProjectId
  GatewayIP: deployGateway.outputs.GatewayIP
}

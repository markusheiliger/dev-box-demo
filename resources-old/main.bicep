targetScope = 'subscription'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

@description('The project defintion to process')
param ProjectDefinition object

@description('The Windows 365 principal id')
param Windows365PrinicalId string

// ============================================================================================

var Extensions = {
  Bastion: false     // deploy bastion host on the organization (hub) network to manage shared resources
  Firewall: false    // deploy a firewall on the organization (hub) network to manage network / resource access
  Gateway: false    // deploy a VPN gateway on the organization (hub) network to connect external networks / resources
  Services: false    // deploy shared service on the organization (hub) network and make them available to all projects
}

// ============================================================================================

resource organizationResourceGroup 'Microsoft.Resources/resourceGroups@2019-10-01' = {
  name: 'ORG-${OrganizationDefinition.name}'
  location: OrganizationDefinition.location
  properties: {}
}

module deployOrganization 'deployOrganization.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString(OrganizationDefinition.name)}'
  scope: organizationResourceGroup
  params:{
    OrganizationDefinition: OrganizationDefinition
    Windows365PrinicalId: Windows365PrinicalId
  }
}

resource servicesResourceGroup 'Microsoft.Resources/resourceGroups@2019-10-01' = if (Extensions.Services) {
  name: 'ORG-${OrganizationDefinition.name}-Services'
  location: OrganizationDefinition.location
  properties: {}
}

module deployOrganizationServices 'deployOrganization-Services.bicep' = if (Extensions.Services) {
  name: '${take(deployment().name, 36)}_${uniqueString('deployOrganizationResources')}'
  scope: servicesResourceGroup
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationNetworkId: deployOrganization.outputs.OrganizationNetworkId
    OrganizationWorkspaceId: deployOrganization.outputs.OrganizationWorkspaceId
  }
}

resource bastionResourceGroup 'Microsoft.Resources/resourceGroups@2019-10-01' = if (Extensions.Bastion) {
  name: 'ORG-${OrganizationDefinition.name}-Bastion'
  location: OrganizationDefinition.location
  properties: {}
}

module deployOrganizationBastion 'deployOrganization-Bastion.bicep' = if (Extensions.Bastion) {
  name: '${take(deployment().name, 36)}_${uniqueString('deployOrganizationBastion')}'
  scope: bastionResourceGroup
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationNetworkId: deployOrganization.outputs.OrganizationNetworkId
    OrganizationWorkspaceId: deployOrganization.outputs.OrganizationWorkspaceId
  }
}

module deployOrganizationGateway 'deployOrganization-Gateway.bicep' = if (Extensions.Gateway) {
  name: '${take(deployment().name, 36)}_${uniqueString('deployOrganizationGateway')}'
  scope: organizationResourceGroup
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationNetworkId: deployOrganization.outputs.OrganizationNetworkId
    OrganizationWorkspaceId: deployOrganization.outputs.OrganizationWorkspaceId
  }
}

module deployOrganizationFirewall 'deployOrganization-Firewall.bicep' = if (Extensions.Firewall) {
  name: '${take(deployment().name, 36)}_${uniqueString('deployOrganizationFirewall')}'
  scope: organizationResourceGroup
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationNetworkId: deployOrganization.outputs.OrganizationNetworkId
    OrganizationWorkspaceId: deployOrganization.outputs.OrganizationWorkspaceId
  }
}

resource projectResourceGroup 'Microsoft.Resources/resourceGroups@2019-10-01' = {
  name: 'PRJ-${OrganizationDefinition.name}-${ProjectDefinition.name}'
  location: OrganizationDefinition.location
  properties: {}
}

resource privateLinksResourceGroup 'Microsoft.Resources/resourceGroups@2019-10-01' = {
  name: 'PRJ-${OrganizationDefinition.name}-${ProjectDefinition.name}-PL'
  location: OrganizationDefinition.location
  properties: {}
}

module deployProject 'deployProject.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployProject')}'
  scope: projectResourceGroup
  params:{
    OrganizationDefinition: OrganizationDefinition
    OrganizationNetworkId: deployOrganization.outputs.OrganizationNetworkId
    OrganizationDevCenterId: deployOrganization.outputs.OrganizationDevCenterId
    OrganizationGatewayIpAddress: Extensions.Firewall ? deployOrganizationFirewall.outputs.GatewayIPAddress : ''
    ProjectDefinition: ProjectDefinition
    ProjectPrivateLinkResourceGroupId: privateLinksResourceGroup.id
  }
}

// ============================================================================================



targetScope = 'resourceGroup'

// ============================================================================================

param OrganizationDefinition object

param ProjectDefinition object

param ProjectNetworkId string

param ProjectGatewayIP string

param EnvironmentDefinition object

param DeploymentIdentityId string

// ============================================================================================

var DNSZoneName = '${EnvironmentDefinition.name}.${ProjectDefinition.name}.${OrganizationDefinition.zone}'
var DeploymentIdentityIdSegments = split(DeploymentIdentityId, '/')

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: EnvironmentDefinition.name
  location: OrganizationDefinition.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        EnvironmentDefinition.ipRange
      ]
    }
  }
}

resource routeTable 'Microsoft.Network/routeTables@2022-07-01' = if (!empty(ProjectGatewayIP)) {
  name: EnvironmentDefinition.name
  location: OrganizationDefinition.location
}

resource route 'Microsoft.Network/routeTables/routes@2022-07-01' = [for (subnet, subnetIndex) in OrganizationDefinition.network.subnets: if (!empty(ProjectGatewayIP) && subnet.routable){
  name: '${ProjectDefinition.name}-GW-${subnetIndex}'
  parent: routeTable
  properties: {
    addressPrefix: subnet.ipRange
    nextHopIpAddress: ProjectGatewayIP
    nextHopType: 'VirtualAppliance'
  }
}]

resource defaultSubNetwork 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  name: 'default'
  parent: virtualNetwork
  properties: {
    addressPrefix: EnvironmentDefinition.ipRange
    privateEndpointNetworkPolicies: 'Disabled'
    routeTable: empty(ProjectGatewayIP) ? null : {
      id: routeTable.id
    }
  }
}

module deployJumpHost 'deployJumpHost.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployJumpHost')}'
  params: {
    JumpHostNetworkId: defaultSubNetwork.id
    JumpHostPrefix: EnvironmentDefinition.name
    JumpHostLocation: OrganizationDefinition.location
  }
}

module peerNetworks 'peerNetworks.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('peerNetworks', ProjectNetworkId, virtualNetwork.id)}'
  scope: subscription()
  params: {
    HubNetworkId: ProjectNetworkId
    SpokeNetworkId: virtualNetwork.id
  }
}
resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: DNSZoneName
  location: 'global'
}

resource privateDnsZoneLink_environment 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'Environment'
  location: 'global'
  parent: privateDnsZone
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource privateDnsZoneLink_project 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'Project'
  location: 'global'
  parent: privateDnsZone
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: ProjectNetworkId
    }
  }
}

resource deploymentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: last(DeploymentIdentityIdSegments)
  scope: resourceGroup(DeploymentIdentityIdSegments[2], DeploymentIdentityIdSegments[4])
}

module deployCustomRoleDefintions 'deployCustomRoleDefinitions.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployCustomRoleDefintions')}'
  scope: subscription()
}

resource environmentDeployerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, deploymentIdentity.id)
  scope: resourceGroup()
  properties: {
    principalId: deploymentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: deployCustomRoleDefintions.outputs.environmentDeployerRoleDefinitionId
  }
}

// ============================================================================================

output EnvironmentNetworkId string = virtualNetwork.id
output DeploymentIdentityId string = deploymentIdentity.id

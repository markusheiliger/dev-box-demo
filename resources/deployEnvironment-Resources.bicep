targetScope = 'resourceGroup'

// ============================================================================================

param OrganizationDefinition object

param ProjectDefinition object

param ProjectNetworkId string

param EnvironmentDefinition object

param DeploymentIdentityId string

// ============================================================================================

var DNSZoneName = '${EnvironmentDefinition.name}.${ProjectDefinition.name}.${OrganizationDefinition.zone}'
var DeploymentIdentityIdSegments = split(DeploymentIdentityId, '/')

// ============================================================================================

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'Network'
  location: OrganizationDefinition.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        EnvironmentDefinition.ipRange
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: EnvironmentDefinition.ipRange
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
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

resource environmentDeployerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b2780688-3ab3-45cc-83d2-f1c264322d93' // Custom Role - check main template for details
}

resource environmentDeployerRoleAssignment_privateDnsZone 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(privateDnsZone.id, environmentDeployerRoleDefinition.id, deploymentIdentity.id)
  scope: privateDnsZone
  properties: {
    principalId: deploymentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: environmentDeployerRoleDefinition.id
  }
}

resource environmentDeployerRoleAssignment_virtualNetwork 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(virtualNetwork.id, environmentDeployerRoleDefinition.id, deploymentIdentity.id)
  scope: virtualNetwork
  properties: {
    principalId: deploymentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: environmentDeployerRoleDefinition.id
  }
}

// ============================================================================================

output EnvironmentNetworkId string = virtualNetwork.id
output DeploymentIdentityId string = deploymentIdentity.id

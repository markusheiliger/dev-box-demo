targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

param OrganizationDevCenterId string

@description('The project defintion to process')
param ProjectDefinition object

param ProjectNetworkId string

param ProjectPrivateLinkResourceGroupId string

@description('The environment defintion to process')
param EnvironmentDefinition object

// ============================================================================================

var OrganizationDevCenterIdSegments = split(OrganizationDevCenterId, '/')
var DNSZoneName = '${EnvironmentDefinition.name}.${ProjectDefinition.name}.${OrganizationDefinition.zone}'

// ============================================================================================

resource deploymentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${EnvironmentDefinition.name}-Deploy'
  location: OrganizationDefinition.location
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: '${EnvironmentDefinition.name}-Network'
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

resource privateDnsZoneContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b12aa53e-6015-4669-85d0-8515ebb3ae7f' // https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#private-dns-zone-contributor
}

resource privateDnsZoneContributorRoleAssignment_privateDnsZone 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(privateDnsZone.id, privateDnsZoneContributorRoleDefinition.id, deploymentIdentity.id)
  scope: privateDnsZone
  properties: {
    principalId: deploymentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: privateDnsZoneContributorRoleDefinition.id
  }
}

resource privateDnsZoneContributorRoleAssignment_virtualNetwork 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(virtualNetwork.id, privateDnsZoneContributorRoleDefinition.id, deploymentIdentity.id)
  scope: virtualNetwork
  properties: {
    principalId: deploymentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: privateDnsZoneContributorRoleDefinition.id
  }
}

resource project 'Microsoft.DevCenter/projects@2022-10-12-preview' existing = {
  name: ProjectDefinition.name
}

resource environment 'Microsoft.DevCenter/projects/environmentTypes@2022-10-12-preview' = {
  name: EnvironmentDefinition.name
  parent: project
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${deploymentIdentity.id}': {}
    }
  }
  tags: {
    EnvironmentNetworkId: virtualNetwork.id
    PrivateLinkResourceGroupId: ProjectPrivateLinkResourceGroupId
    DeploymentIdentityId: deploymentIdentity.id
  }
  properties: {
    #disable-next-line use-resource-id-functions
    deploymentTargetId: '/subscriptions/${EnvironmentDefinition.subscription}'
    status: 'Enabled'
  }
}

resource devCenter 'Microsoft.DevCenter/devcenters@2022-10-12-preview' existing = {
  name: last(OrganizationDevCenterIdSegments)
  scope: resourceGroup(OrganizationDevCenterIdSegments[2], OrganizationDevCenterIdSegments[4])
}

module initSubscription 'initSubscription.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('initSubscription', EnvironmentDefinition.subscription)}'
  scope: subscription(EnvironmentDefinition.subscription)
  params: {
    DevCenterIdentity: devCenter.identity.principalId
    DeploymentIdentity: deploymentIdentity.properties.principalId
  }
}

// ============================================================================================

output EnvironmentNetworkId string = virtualNetwork.id
output DeploymentPrincipalId string = deploymentIdentity.properties.principalId

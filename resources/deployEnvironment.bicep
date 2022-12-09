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

// ============================================================================================

resource devCenter 'Microsoft.DevCenter/devcenters@2022-10-12-preview' existing = {
  name: last(OrganizationDevCenterIdSegments)
  scope: resourceGroup(OrganizationDevCenterIdSegments[2], OrganizationDevCenterIdSegments[4])
}

resource project 'Microsoft.DevCenter/projects@2022-10-12-preview' existing = {
  name: ProjectDefinition.name
}

resource deploymentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${EnvironmentDefinition.name}-Deployer'
  location: OrganizationDefinition.location
}

resource managedIdentityOperatorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'f1a07417-d97a-45cb-824c-7a7467783830' // https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#managed-identity-operator
}

resource managedIdentityOperatorRoleRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(deploymentIdentity.id, managedIdentityOperatorRoleDefinition.id, deploymentIdentity.id)
  scope: deploymentIdentity
  properties: {
    principalId: deploymentIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: managedIdentityOperatorRoleDefinition.id
  }
}

module deployEnvironmentSubscription 'deployEnvironment-Subscription.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployEnvironmentSubscription', EnvironmentDefinition.subscription)}'
  scope: subscription(EnvironmentDefinition.subscription)
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationDevCenterId: devCenter.id
    ProjectDefinition: ProjectDefinition
    ProjectNetworkId: ProjectNetworkId
    EnvironmentDefinition: EnvironmentDefinition
    DeploymentIdentityId: deploymentIdentity.id
  }
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
    PrivateLinkAutomationIdentityId: deploymentIdentity.id
    PrivateLinkResourceGroupId: ProjectPrivateLinkResourceGroupId
  }
  properties: {
    #disable-next-line use-resource-id-functions
    deploymentTargetId: '/subscriptions/${EnvironmentDefinition.subscription}'
    status: 'Enabled'
  }
}


// ============================================================================================

output EnvironmentNetworkId string = deployEnvironmentSubscription.outputs.EnvironmentNetworkId
output DeploymentPrincipalId string = deploymentIdentity.properties.principalId

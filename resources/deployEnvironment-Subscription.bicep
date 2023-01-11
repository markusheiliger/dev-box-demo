targetScope = 'subscription'

// ============================================================================================

param OrganizationDefinition object

param OrganizationDevCenterId string

param ProjectDefinition object

param ProjectNetworkId string

param EnvironmentDefinition object

param EnvironmentTypeId string

param DeploymentIdentityId string

// ============================================================================================

var OrganizationDevCenterIdSegments = split(OrganizationDevCenterId, '/')

// ============================================================================================

resource devCenter 'Microsoft.DevCenter/devcenters@2022-10-12-preview' existing = {
  name: last(OrganizationDevCenterIdSegments)
  scope: resourceGroup(OrganizationDevCenterIdSegments[2], OrganizationDevCenterIdSegments[4])
}

resource ownerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' // https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner
}

resource ownerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, ownerRoleDefinition.id, devCenter.id)
  properties: {
    principalId: devCenter.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: ownerRoleDefinition.id
  }
}

resource environmentResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'Environment-${EnvironmentTypeId}'
  location: OrganizationDefinition.location
  tags: {
    EnvironmentTypeName: EnvironmentDefinition.name
  }
}

module deployEnvironmentResources 'deployEnvironment-Resources.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployEnvironmentResources')}'
  scope: environmentResourceGroup
  params: {
    OrganizationDefinition: OrganizationDefinition
    EnvironmentDefinition: EnvironmentDefinition
    ProjectDefinition: ProjectDefinition
    ProjectNetworkId: ProjectNetworkId
    DeploymentIdentityId: DeploymentIdentityId
  }
}

// ============================================================================================

output EnvironmentNetworkId string = deployEnvironmentResources.outputs.EnvironmentNetworkId

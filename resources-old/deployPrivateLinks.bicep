targetScope = 'resourceGroup'

// ============================================================================================

param ProjectNetworkId string

param EnvironmentNetworkIds array = []

param DeploymentPrincipalIds array = []

// ============================================================================================

var PreProvisionPrivateLinkDnsZoneNames = [
  'privatelink.vaultcore.azure.net'
  'privatelink.azconfig.io'
  'privatelink${environment().suffixes.sqlServerHostname}'
]

// we utilize the union function to remove duplicates from the PreProvisionPrivateLinkDnsZoneNames array
var PrivateLinkDnsZoneNames = union(PreProvisionPrivateLinkDnsZoneNames, PreProvisionPrivateLinkDnsZoneNames)

// ============================================================================================

resource tags 'Microsoft.Resources/tags@2021-04-01' = {
  name: 'default'
  scope: resourceGroup()
  properties: {
    tags: {
      ProjectNetworkId: ProjectNetworkId
    }
  }
}

module deployCustomRoleDefintions 'deployCustomRoleDefinitions.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployCustomRoleDefintions')}'
  scope: subscription()
}

resource environmentDeployerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for DeploymentPrincipalId in DeploymentPrincipalIds : {
  name: guid(resourceGroup().id, DeploymentPrincipalId)
  scope: resourceGroup()
  properties: {
    principalId: DeploymentPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: deployCustomRoleDefintions.outputs.environmentDeployerRoleDefinitionId
  }
}]

module deployPrivateLinkZone 'deployPrivateLinks-Zone.bicep' = [ for PrivateLinkDnsZoneName in PrivateLinkDnsZoneNames : {
  name: '${take(deployment().name, 36)}_${uniqueString('deployPrivateLinkZone', PrivateLinkDnsZoneName)}'
  params: {
    PrivateLinkDnsZoneName: PrivateLinkDnsZoneName
    ProjectNetworkId: ProjectNetworkId
    EnvironmentNetworkIds: EnvironmentNetworkIds
  }
}]

// ============================================================================================


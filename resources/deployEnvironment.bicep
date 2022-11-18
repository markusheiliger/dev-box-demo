targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

@description('The project defintion to process')
#disable-next-line no-unused-params
param ProjectDefinition object

@description('The environment definition to process')
#disable-next-line no-unused-params
param ProjectSettings object

@description('The environment settings to process')
param EnvironmentSettings object

// ============================================================================================

var PrivateDnsZones = [
  'privatelink.azurewebsites.net'
  'privatelink${environment().suffixes.sqlServerHostname}'
]

// ============================================================================================

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = {
  name: 'Environment'
  location: OrganizationDefinition.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        EnvironmentSettings.ipRange
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: EnvironmentSettings.ipRange
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

resource virtualNetwork_contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(virtualNetwork.id, contributorRoleDefinition.id, EnvironmentSettings.identityPrincipalId)
  scope: virtualNetwork
  properties: {
    principalId: EnvironmentSettings.identityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleDefinition.id
  }
}

resource privateDnsZone  'Microsoft.Network/privateDnsZones@2020-06-01' = [for PrivateDnsZoneName in PrivateDnsZones: {
  name: PrivateDnsZoneName
  location: 'global'
}]

resource privateDnsZone_contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (PrivateDnsZoneName, PrivateDnsZoneIndex) in PrivateDnsZones: {
  name: guid(privateDnsZone[PrivateDnsZoneIndex].id, contributorRoleDefinition.id, EnvironmentSettings.identityPrincipalId)
  scope: privateDnsZone[PrivateDnsZoneIndex]
  properties: {
    principalId: EnvironmentSettings.identityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleDefinition.id
  }
}]

resource privateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = [for (PrivateDnsZoneName, PrivateDnsZoneIndex) in PrivateDnsZones: {
  name: virtualNetwork.name
  location: 'global'
  parent: privateDnsZone[PrivateDnsZoneIndex]
  properties: {
    registrationEnabled: true
    virtualNetwork: virtualNetwork
  }
}]

// ============================================================================================

output EnvironmentNetworkId string = virtualNetwork.id

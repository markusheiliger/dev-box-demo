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

@description('The environment defintion to process')
#disable-next-line no-unused-params
param EnvironmentDefinition object

@description('The environment settings to process')
param EnvironmentSettings object

// ============================================================================================

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c' // https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor
}

resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, contributorRoleDefinition.id, EnvironmentSettings.identityPrincipalId)
  scope: resourceGroup()
  properties: {
    principalId: EnvironmentSettings.identityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleDefinition.id
  }
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

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: '${EnvironmentDefinition.name}.${ProjectDefinition.name}.${OrganizationDefinition.zone}'
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
      id: ProjectSettings.networkId
    }
  }
}

// ============================================================================================

output EnvironmentNetworkId string = virtualNetwork.id

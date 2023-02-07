targetScope = 'resourceGroup'

// ============================================================================================

param VNetName string 

param RoutesName string

param DnsServers array

// ============================================================================================

#disable-next-line no-loc-expr-outside-params
var ResourceLocation = resourceGroup().location

// ============================================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' existing = {
  name: VNetName
}

resource routes 'Microsoft.Network/routeTables@2022-07-01' existing = {
  name: RoutesName
} 

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${vnet.name}-DNS'
  location: ResourceLocation
}

resource contributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource contributorRoleAssignmentVnet 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(vnet.id, contributorRoleDefinition.id, identity.id)
  scope: vnet
  properties: {
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleDefinition.id    
  }
}

resource contributorRoleAssignmentRoutes 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(routes.id, contributorRoleDefinition.id, identity.id)
  scope: routes
  properties: {
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRoleDefinition.id    
  }
}

resource setDnsServers 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: '${vnet.name}-DNS'
  location: ResourceLocation
  dependsOn: [
    contributorRoleAssignmentVnet
    contributorRoleAssignmentRoutes
  ]
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: guid(string(DnsServers))
    azCliVersion: '2.42.0'
    timeout: 'PT30M'
    scriptContent: 'az network vnet update --subscription ${subscription().subscriptionId} --resource-group ${resourceGroup().name} --name ${VNetName} --dns-servers \'${join(DnsServers, '\' \'')}\''
    cleanupPreference: 'Always'
    retentionInterval: 'P1D'
  }
}

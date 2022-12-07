targetScope = 'resourceGroup'

// ============================================================================================

param ProjectNetworkId string

param EnvironmentNetworkIds array = []

param DeploymentPrincipalIds array = []

// ============================================================================================

var PreProvisionPrivateLinkDnsZoneNames = [
  'privatelink.azure-automation.net'
  'privatelink${environment().suffixes.sqlServerHostname}'
  // 'privatelink.{dnsPrefix}.database.windows.net'
  'privatelink.sql.azuresynapse.net'
  'privatelink.dev.azuresynapse.net'
  'privatelink.azuresynapse.net'
  'privatelink.blob${environment().suffixes.storage}'
  'privatelink.table${environment().suffixes.storage}'
  'privatelink.queue${environment().suffixes.storage}'
  'privatelink.file${environment().suffixes.storage}'
  'privatelink.web${environment().suffixes.storage}'
  'privatelink.dfs${environment().suffixes.storage}'
  'privatelink.documents.azure.com'
  'privatelink.mongo.cosmos.azure.com'
  'privatelink.cassandra.cosmos.azure.com'
  'privatelink.gremlin.cosmos.azure.com'
  'privatelink.table.cosmos.azure.com'
  'privatelink.batch.azure.com'
  'privatelink.postgres.database.azure.com'
  'privatelink.mysql.database.azure.com'
  'privatelink.mariadb.database.azure.com'
  'privatelink.vaultcore.azure.net'
  'privatelink.managedhsm.azure.net'
  'privatelink.${resourceGroup().location}.azmk8s.io'
  // '{subzone}.privatelink.${resourceGroup().location}.azmk8s.io'
  'privatelink.search.windows.net'
  'privatelink.azurecr.io'
  '${resourceGroup().location}.privatelink.azurecr.io'
  'privatelink.azconfig.io'
  'privatelink.${resourceGroup().location}.backup.windowsazure.com'
  '${resourceGroup().location}.privatelink.siterecovery.windowsazure.com'
  'privatelink.servicebus.windows.net'
  'privatelink.azure-devices.net'
  'privatelink.servicebus.windows.net1'
  'privatelink.servicebus.windows.net'
  'privatelink.eventgrid.azure.net'
  'privatelink.azurewebsites.net'
  'scm.privatelink.azurewebsites.net'
  'privatelink.api.azureml.ms'
  'privatelink.notebooks.azure.net'
  'privatelink.service.signalr.net'
  'privatelink.monitor.azure.com'
  'privatelink.oms.opinsights.azure.com'
  'privatelink.ods.opinsights.azure.com'
  'privatelink.agentsvc.azure-automation.net'
  'privatelink.blob${environment().suffixes.storage}'
  'privatelink.cognitiveservices.azure.com'
  '${resourceGroup().location}.privatelink.afs.azure.net'
  'privatelink.datafactory.azure.net'
  'privatelink.adf.azure.com'
  'privatelink.redis.cache.windows.net'
  'privatelink.redisenterprise.cache.azure.net'
  'privatelink.purview.azure.com'
  'privatelink.purviewstudio.azure.com'
  'privatelink.digitaltwins.azure.net'
  'privatelink.azurehdinsight.net'
  'privatelink.his.arc.azure.com'
  'privatelink.guestconfiguration.azure.com'
  'privatelink.kubernetesconfiguration.azure.com'
  'privatelink.media.azure.net'
  'privatelink.${resourceGroup().location}.kusto.windows.net'
  'privatelink.azurestaticapps.net'
  // 'privatelink.{partitionId}.azurestaticapps.net'
  'privatelink.prod.migration.windowsazure.com'
  'privatelink.azure-api.net'
  'privatelink.developer.azure-api.net'
  'privatelink.analysis.windows.net'
  'privatelink.pbidedicated.windows.net'
  'privatelink.tip1.powerquery.microsoft.com'
  'privatelink.directline.botframework.com'
  'privatelink.token.botframework.com'
  'workspace.privatelink.azurehealthcareapis.com'
  'fhir.privatelink.azurehealthcareapis.com'
  'dicom.privatelink.azurehealthcareapis.com'
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

resource privateDnsZoneContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b12aa53e-6015-4669-85d0-8515ebb3ae7f' // https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#private-dns-zone-contributor
}

resource privateDnsZoneContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for DeploymentPrincipalId in DeploymentPrincipalIds : {
  name: guid(resourceGroup().id, privateDnsZoneContributorRoleDefinition.id, DeploymentPrincipalId)
  scope: resourceGroup()
  properties: {
    principalId: DeploymentPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: privateDnsZoneContributorRoleDefinition.id
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


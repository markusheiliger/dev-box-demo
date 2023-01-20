targetScope = 'resourceGroup'

// ============================================================================================

@description('The organization defintion to process')
param OrganizationDefinition object

@description('The organization Network id')
param OrganizationNetworkId string

@description('The organization DevCenter id')
param OrganizationDevCenterId string

param OrganizationGatewayIpAddress string

@description('The project defintion to process')
param ProjectDefinition object

param ProjectPrivateLinkResourceGroupId string

// ============================================================================================

var ProjectPrivateLinkResourceGroupIdSegments = split(ProjectPrivateLinkResourceGroupId, '/')
var OrganizationDevCenterIdSegments = split(OrganizationDevCenterId, '/')
var Environments = contains(ProjectDefinition, 'environments') ? ProjectDefinition.environments : []
var DevBoxes = contains(OrganizationDefinition, 'devboxes') ? OrganizationDefinition.devboxes : []
var ProjectAdmins = contains(ProjectDefinition, 'admins') ? ProjectDefinition.admins : []
var ProjectUsers = contains(ProjectDefinition, 'users') ? ProjectDefinition.users : []

var ProjectSettings = contains(ProjectDefinition, 'settings') ? ProjectDefinition.settings : {}
var ProjectSecrets = contains(ProjectDefinition, 'secrets') ? ProjectDefinition.secrets : {}

// ============================================================================================

resource project 'Microsoft.DevCenter/projects@2022-10-12-preview' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
  properties: {
    devCenterId: OrganizationDevCenterId
  }
}

resource projectAdminRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: '331c37c6-af14-46d9-b9f4-e1909e1b95a0'
}

resource projectAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for PrincipalId in ProjectAdmins: if (!empty(PrincipalId)) {
  name: guid(project.id, projectAdminRoleDefinition.id, PrincipalId)
  scope: project
  properties: {
    roleDefinitionId: projectAdminRoleDefinition.id
    principalId: PrincipalId
  }
}] 

resource devBoxUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: '45d50f46-0b78-4001-a660-4198cbe8cd05'
}

resource devBoxUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for PrincipalId in ProjectUsers: if (!empty(PrincipalId)) {
  name: guid(project.id, devBoxUserRoleDefinition.id, PrincipalId)
  scope: project
  properties: {
    roleDefinitionId: devBoxUserRoleDefinition.id
    principalId: PrincipalId
  }
}] 

resource deploymentEnvironmentUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: '18e40d4e-8d2e-438d-97e1-9528336e149c'
}

resource deploymentEnvironmentUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = [for PrincipalId in ProjectUsers: if (!empty(PrincipalId)) {
  name: guid(project.id, deploymentEnvironmentUserRoleDefinition.id, PrincipalId)
  scope: project
  properties: {
    roleDefinitionId: deploymentEnvironmentUserRoleDefinition.id
    principalId: PrincipalId
  }
}] 

// resource routeTable 'Microsoft.Network/routeTables@2022-07-01' = if (!empty(OrganizationGatewayIpAddress)) {
//   name: ProjectDefinition.name
//   location: OrganizationDefinition.location
//   properties: {
//     disableBgpRoutePropagation: false
//     routes: [
//       {
//         name: 'RouteTrafficToOrganizationGateway'
//         properties: {
//           nextHopType: 'VirtualAppliance'
//           addressPrefix: '0.0.0.0/0'
//           nextHopIpAddress: OrganizationGatewayIpAddress
//         }
//       }
//     ]
//   }
// }

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
  properties: {
    addressSpace: {
      addressPrefixes: [
        ProjectDefinition.ipRange
      ]
    }
  }
}

resource defaultSubNetwork 'Microsoft.Network/virtualNetworks/subnets@2022-07-01' = {
  name: 'default'
  parent: virtualNetwork
  properties: {
    addressPrefix: ProjectDefinition.ipRange
    // routeTable: empty(OrganizationGatewayIpAddress) ? null : {
    //   id: routeTable.id
    // }
  }
}

module deployGateway 'deployProject-Gateway.bicep' = if (!empty(contains(ProjectDefinition, 'gateway') ? ProjectDefinition.gateway : {})) {
  name: '${take(deployment().name, 36)}_${uniqueString('deployWireGuard')}'
  scope: resourceGroup()
  params: {
    GatewayNetworkId: defaultSubNetwork.id
    GatewayDefinition: ProjectDefinition.gateway
    OrganizationDefinition: OrganizationDefinition
    ProjectDefinition: ProjectDefinition
  }
}

module peerNetworks 'peerNetworks.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('peerNetworks', OrganizationNetworkId, virtualNetwork.id)}'
  scope: subscription()
  params: {
    HubNetworkId: OrganizationNetworkId
    HubGatewayIPAddress: OrganizationGatewayIpAddress
    SpokeNetworkId: virtualNetwork.id
  }
}

resource privateDnsZone  'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: '${ProjectDefinition.name}.${OrganizationDefinition.zone}'
  location: 'global'
}

resource privateDnsZoneLink_project 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'Project'
  location: 'global'
  parent: privateDnsZone
  properties: {
    registrationEnabled: true
    virtualNetwork: {
      id: virtualNetwork.id
    }
  }
}

resource privateDnsZoneLink_organization 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'Organization'
  location: 'global'
  parent: privateDnsZone
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: OrganizationNetworkId
    }
  }
}

resource networkConnection 'Microsoft.DevCenter/networkConnections@2022-10-12-preview' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
  properties: {
    domainJoinType: 'AzureADJoin'
    subnetId: defaultSubNetwork.id
    networkingResourceGroupName: '${resourceGroup().name}-NI'
  }
}

module attachNetworkConnection 'attachNetworkConnection.bicep' = {
  name:'${take(deployment().name, 36)}_${uniqueString('attachNetworkConnection', networkConnection.id)}'
  scope: resourceGroup(OrganizationDevCenterIdSegments[2], OrganizationDevCenterIdSegments[4])
  params: {
    DevCenterName: last(OrganizationDevCenterIdSegments)
    NetworkConnectionId: networkConnection.id
  }
}

resource devBoxPool 'Microsoft.DevCenter/projects/pools@2022-10-12-preview' = [for DevBox in DevBoxes: {
  name: '${DevBox.name}Pool'
  location: OrganizationDefinition.Location
  parent: project
  dependsOn: [
    attachNetworkConnection
  ]
  properties: {
    devBoxDefinitionName: DevBox.name
    networkConnectionName: networkConnection.name
    licenseType: 'Windows_Client'
    localAdministrator: 'Enabled'
  }
}]

resource projectSecrets 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource projectSettings 'Microsoft.AppConfiguration/configurationStores@2022-05-01' = {
  name: ProjectDefinition.name
  location: OrganizationDefinition.location
  sku: {
    name: 'standard'
  }
  identity: {
    type: 'SystemAssigned'   
  }
  properties: {
    // disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

resource vaultSecretUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource vaultSecretUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(projectSecrets.id, vaultSecretUserRoleDefinition.id, projectSettings.id)
  scope: projectSecrets
  properties: {
    principalType: 'ServicePrincipal'
    principalId: projectSettings.identity.principalId
    roleDefinitionId: vaultSecretUserRoleDefinition.id
  }
}

module deploySettings 'deploySettings.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deploySettings')}'
  scope: resourceGroup()
  params: {
    ConfigurationStoreName: projectSettings.name
    ConfigurationVaultName: projectSecrets.name
    Settings: union(ProjectSettings, {
      ProjectNetworkId: virtualNetwork.id
      PrivateLinkResourceGroupId: ProjectPrivateLinkResourceGroupId
    })
    Secrets: union(ProjectSecrets, {

    })
  }
}

module deployEnvironment 'deployEnvironment.bicep' = [for Environment in Environments: {
  name: '${take(deployment().name, 36)}_${uniqueString('deployEnvironment', Environment.name)}'
  scope: resourceGroup()
  dependsOn: [
    deploySettings
  ]
  params: {
    OrganizationDefinition: OrganizationDefinition
    OrganizationDevCenterId: OrganizationDevCenterId
    ProjectDefinition: ProjectDefinition
    ProjectConfigurationUrl: projectSettings.properties.endpoint
    ProjectSettingsId: projectSettings.id
    ProjectSecretsId: projectSecrets.id
    ProjectNetworkId: virtualNetwork.id
    ProjectGatewayIP: deployGateway.outputs.GatewayIP
    ProjectPrivateLinkResourceGroupId: ProjectPrivateLinkResourceGroupId
    EnvironmentDefinition: Environment
  }
}]

module deployPrivateLinks 'deployPrivateLinks.bicep' = {
  name: '${take(deployment().name, 36)}_${uniqueString('deployPrivateLinks', project.id)}'
  scope: resourceGroup(ProjectPrivateLinkResourceGroupIdSegments[2], ProjectPrivateLinkResourceGroupIdSegments[4])
  params: {
    ProjectNetworkId: virtualNetwork.id
    EnvironmentNetworkIds: [for i in range(0, length(Environments)): deployEnvironment[i].outputs.EnvironmentNetworkId]
    DeploymentPrincipalIds: [for i in range(0, length(Environments)): deployEnvironment[i].outputs.DeploymentPrincipalId]
  }
}

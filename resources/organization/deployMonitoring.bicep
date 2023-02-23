targetScope = 'resourceGroup'

// ============================================================================================

param OrganizationDefinition object

// ============================================================================================

resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${OrganizationDefinition.name}-LA'
  location: OrganizationDefinition.location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

// ============================================================================================

output WorkspaceId string = workspace.id

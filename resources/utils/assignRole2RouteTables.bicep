targetScope = 'resourceGroup'

// ============================================================================================

param ResourceIds array

param PrincipalId string

param RoleDefinitionName string

// ============================================================================================

module assignRole 'assignRole2RouteTable.bicep' = [for resourceId in ResourceIds: {
  name: '${take(deployment().name, 36)}_${uniqueString('routeTable', resourceId, PrincipalId, RoleDefinitionName)}'
  scope: resourceGroup(split(resourceId, '/')[2], split(resourceId, '/')[4])
  params: {
    ResourceName: last(split(resourceId, '/')[4])
    PrincipalId: PrincipalId
    RoleDefinitionName: RoleDefinitionName
  }
}]

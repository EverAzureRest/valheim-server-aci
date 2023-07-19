
param functionAppId string
param functionAppPrincipalId string
param roleDefinitionId string

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(functionAppId, resourceGroup().id, roleDefinitionId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roldefinitions', roleDefinitionId)
    principalId:  functionAppPrincipalId
  }
  scope: resourceGroup()
}

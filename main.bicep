targetScope = 'subscription'

@description('Prefix for the Function App Name')
param functionAppPrefix string = 'vhserver'

@description('Prefix for the Storage Account Name')
param storageAccountPrefix string = 'vhfnstorage'

@description('Prfix for the Game Data Storage Account Name')
param gameDataStorageAccountPrefix string = 'vhgdstorage'

@description('Resource Group Name for infra Resources')
param resourceGroupName string = 'vallheim'

@description('Resource Group Name for Container Instances')
param containerResourceGroupName string = 'vallheim-containers'

@description('Container Registry Name')
param containerRegistryName string = 'vhbuild'

param deploymentLocation string = deployment().location

param roleDefinitionName string = 'appServiceCustomRole'

var roleDefinitionGuid = guid(subscription().subscriptionId)

resource containerResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: containerResourceGroupName
  location: deploymentLocation
}

resource infraResourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' existing = {
  name: resourceGroupName
}

resource roleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' = {
  name: roleDefinitionGuid
  properties: {
    roleName: '${roleDefinitionName} ${roleDefinitionGuid}'
    description: 'Role Definition for Manged Identity of the VPN Service fabric'
    type: 'CustomRole'
    permissions: [
      {
        actions: [
          'Microsoft.Resources/deployments/write'
          'Microsoft.Resources/subscriptions/resourcegroups/*'
          'Microsoft.ContainerInstance/containerGroups/*'
        ]
        notActions: [
          'Microsoft.ContainerInstance/containerGroups/containers/exec/action'
          'Microsoft.ContainerInstance/containerGroups/containers/logs/read'
        ]
      }
    ]
    assignableScopes: [
      containerResourceGroup.id
    ]
  }
}

module resourceDeployment 'resources.bicep' = {
  name: 'resourceDeployment'
  scope: infraResourceGroup
  params: {
    functionAppPrefix: functionAppPrefix
    storageAccountPrefix: storageAccountPrefix
    deploymentLocation: deploymentLocation
    containerResourceGroupName: containerResourceGroupName
    gameDataStorageAccountPrefix: gameDataStorageAccountPrefix
    containerRegistryName: containerRegistryName
  }
}

module resourceGroupRoleAssignment 'assignment.bicep' = {
  name: 'resourceGroupRoleAssignment'
  scope: containerResourceGroup
  params: {
    functionAppId: resourceDeployment.outputs.functionAppId
    functionAppPrincipalId: resourceDeployment.outputs.functionAppPrincipalId
    roleDefinitionId: roleDefinitionGuid
  }
}


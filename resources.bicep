targetScope = 'resourceGroup'

@description('Prefix for the Function App Name')
param functionAppPrefix string 

@description('Prefix for the Storage Account Name')
param storageAccountPrefix string

@description('Target Azure Region')
param deploymentLocation string

@description('Container Resource Group Name')
param containerResourceGroupName string

@description('Prefix for the Game Data Storage Account Name')
param gameDataStorageAccountPrefix string

@description('Name of the Azure Container Registry')
param containerRegistryName string

var functionAppName = '${functionAppPrefix}${uniqueString(resourceGroup().id)}'


resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: '${functionAppName}-kv'
  location: deploymentLocation
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    accessPolicies: [
      {
        tenantId: tenant().tenantId
        objectId: functionApp.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}


resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: containerRegistryName
}

resource gameDataStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: '${gameDataStorageAccountPrefix}${uniqueString(resourceGroup().id)}'
  location: deploymentLocation
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2022-09-01' = {
  parent: gameDataStorageAccount
  name: 'default'
}

resource dataShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  parent: fileService
  name: 'gamedata'
}

resource configShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-09-01' = {
  parent: fileService
  name: 'config'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: '${storageAccountPrefix}${uniqueString(resourceGroup().id)}'
  location: deploymentLocation
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    encryption: {
      services: {
        file: {
          enabled: true
        }
        blob: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource appService 'Microsoft.Web/serverfarms@2021-03-01' = {
  name: functionAppName
  location: deploymentLocation
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
    size: 'Y1'
    family: 'Y'
    capacity: 0
  }
  kind: 'functionapp'
  properties: {
    perSiteScaling: false
    reserved: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: functionAppName
  location: deploymentLocation 
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    siteConfig: {
      cors: {
        allowedOrigins: [
          '*'
        ]
      }
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME_VERSION'
          value: '~7'
        }
        {
          name: 'AZURE_RG_NAME'
          value: containerResourceGroupName
        }
        {
          name: 'AZURE_KEYVAULT_NAME'
          value: '${functionAppName}-kv'
        }
        {
          name: 'DATA_SHARE_NAME'
          value: dataShare.name
        }
        {
          name: 'CONFIG_SHARE_NAME'
          value: configShare.name
        }
        {
          name: 'STORAGE_NAME'
          value: gameDataStorageAccount.name
        }
        {
          name: 'STORAGE_KEY'
          value: gameDataStorageAccount.listKeys().keys[0].value
        }
        {
          name: 'REGISTRY_SERVER'
          value: containerRegistry.properties.loginServer
        }
        {
          name: 'REGISTRY_USERNAME'
          value: containerRegistry.listCredentials().username
        }
        {
          name: 'REGISTRY_PASSWORD'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
    }
    serverFarmId: appService.id
    reserved: false
    httpsOnly: true
  }
}

output functionAppId string = functionApp.id
output functionAppPrincipalId string = functionApp.identity.principalId

// SAS token validity parameters
param sasStart string = utcNow()
param sasExpiry string = dateTimeAdd(utcNow(), 'P1Y')

// Function App name
var functionAppName = 'fn-nexus'

// Reference to existing Key Vault (created in main.bicep)
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: 'kv-${uniqueString(resourceGroup().id)}'
}

// Key Vault secret names (env var names are derived: uppercase + underscores)
var secretNames = [
  'browserless-token'
  'dobijecka-tg-chat-id'
  'dobijecka-tg-token'
  'orlen-username'
  'orlen-password'
]

var keyVaultAppSettings = [for secretName in secretNames: {
  name: toUpper(replace(secretName, '-', '_'))
  value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${secretName})'
}]

// Reference existing secrets in Key Vault
resource secrets 'Microsoft.KeyVault/vaults/secrets@2023-07-01' existing = [
  for secretName in secretNames: {
    parent: keyVault
    name: secretName
  }
]

// Storage account for the Function App (required for Flex Consumption)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: 'st${replace(functionAppName, '-', '')}${uniqueString(resourceGroup().id)}'
  location: resourceGroup().location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Blob service (exists by default on storage accounts)
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' existing = {
  parent: storageAccount
  name: 'default'
}

// Table service (exists by default on storage accounts)
resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' existing = {
  parent: storageAccount
  name: 'default'
}

// Deployment container for function app code
resource deploymentContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: '${functionAppName}-deployments'
  properties: {
    publicAccess: 'None'
  }
}

// Results container for function outputs
resource resultsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'nexus-results'
  properties: {
    publicAccess: 'None'
  }
}

// Tankarta table
resource tankartaTable 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-05-01' = {
  parent: tableService
  name: 'tankarta'
}

// Container-level SAS token for read-only access to nexus-results, stored in Key Vault
var serviceSasProperties = {
  canonicalizedResource: '/blob/${storageAccount.name}/${resultsContainer.name}'
  signedResource: 'c'
  signedPermission: 'rl'
  signedProtocol: 'https'
  signedExpiry: sasExpiry
  signedStart: sasStart
}

resource storageSasSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'nexus-results'
  properties: {
    value: '?${storageAccount.listServiceSas('2023-05-01', serviceSasProperties).serviceSasToken}'
  }
}

// User-assigned managed identity for the Function App
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${functionAppName}'
  location: resourceGroup().location
}

// Federated credential for GitHub Actions deployment
resource federatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: managedIdentity
  name: 'github-actions'
  properties: {
    issuer: 'https://token.actions.githubusercontent.com'
    subject: 'repo:skateman/nexus:ref:refs/heads/master'
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

// Flex Consumption plan (serverless, free tier)
resource hostingPlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: 'asp-${functionAppName}'
  location: resourceGroup().location
  sku: {
    tier: 'FlexConsumption'
    name: 'FC1'
  }
  kind: 'functionapp'
  properties: {
    reserved: true
  }
}

// Function App with Flex Consumption
resource functionApp 'Microsoft.Web/sites@2024-11-01' = {
  name: functionAppName
  location: resourceGroup().location
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccount.properties.primaryEndpoints.blob}${deploymentContainer.name}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: managedIdentity.id
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 2048
      }
      runtime: {
        name: 'node'
        version: '22'
      }
    }
    siteConfig: {
      minTlsVersion: '1.2'
      appSettings: concat(
        [
          {
            name: 'AZURE_CLIENT_ID'
            value: '5efaa192-7c8c-48ad-b89a-87d0e226a3bf'
          }
          {
            name: 'AzureWebJobsStorage__accountName'
            value: storageAccount.name
          }
          {
            name: 'AzureWebJobsStorage__blobServiceUri'
            value: storageAccount.properties.primaryEndpoints.blob
          }
          {
            name: 'AzureWebJobsStorage__queueServiceUri'
            value: storageAccount.properties.primaryEndpoints.queue
          }
          {
            name: 'AzureWebJobsStorage__tableServiceUri'
            value: storageAccount.properties.primaryEndpoints.table
          }
          {
            name: 'AzureWebJobsStorage__credential'
            value: 'managedidentity'
          }
          {
            name: 'AzureWebJobsStorage__clientId'
            value: managedIdentity.properties.clientId
          }
          {
            name: 'ORLEN_DISCOUNT'
            value: '2.20'
          }
        ],
        keyVaultAppSettings
      )
    }
    keyVaultReferenceIdentity: managedIdentity.id
  }
}

// Role assignment: Storage Blob Data Owner for the managed identity on the storage account
// Required for deployment container access
resource storageBlobDataOwnerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentity.id, 'Storage Blob Data Owner')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: Storage Account Contributor for the managed identity
resource storageAccountContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentity.id, 'Storage Account Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: Storage Table Data Contributor for the managed identity
// Required for table read/write access
resource storageTableDataContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentity.id, 'Storage Table Data Contributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3')
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignments: Key Vault Secrets User for each specific secret
resource secretRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for (secretName, i) in secretNames: {
    name: guid(secrets[i].id, managedIdentity.id, 'Key Vault Secrets User')
    scope: secrets[i]
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
      principalId: managedIdentity.properties.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

// Role assignment: Website Contributor for GitHub Actions deployment
resource websiteContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(functionApp.id, managedIdentity.id, 'Website Contributor')
  scope: functionApp
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'de139f84-1756-47ae-9be6-808fbbe84772')
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
@description('The resource ID of the Function App')
output functionAppId string = functionApp.id

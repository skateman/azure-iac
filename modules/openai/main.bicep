// Azure OpenAI instance for Home Assistant

@description('Model name to deploy')
param modelName string

@description('Model version to deploy')
param modelVersion string

@description('Deployment capacity (tokens per minute in thousands)')
param capacity int

// Derive name from deployment name
var name = deployment().name

// Create OpenAI account
resource openAIAccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: resourceGroup().location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: '${name}-${uniqueString(resourceGroup().id)}'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Deploy model
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openAIAccount
  name: modelName
  sku: {
    name: 'DataZoneStandard'
    capacity: capacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}

// Outputs
@description('OpenAI account resource ID')
output resourceId string = openAIAccount.id

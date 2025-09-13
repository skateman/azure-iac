// Key Vault module
// Creates an Azure Key Vault for secrets, keys, and certificates management

// Variables
var tenantId = tenant().tenantId
var keyVaultName = 'kv-${uniqueString(resourceGroup().id)}'

// Key Vault resource
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: resourceGroup().location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenantId
    enableSoftDelete: false
    enableRbacAuthorization: true
    enabledForDeployment: true
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: true
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Outputs
@description('The name of the Key Vault')
output keyVaultName string = keyVault.name

@description('The resource ID of the Key Vault')
output keyVaultId string = keyVault.id

@description('The URI of the Key Vault')
output keyVaultUri string = keyVault.properties.vaultUri

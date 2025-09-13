// Key Vault module
// Creates an Azure Key Vault for secrets, keys, and certificates management

@description('Set to true to only calculate the keyvault name without deploying resources')
param lookupOnly bool = false

// Variables
var tenantId = tenant().tenantId
var keyVaultName = 'kv-${uniqueString(resourceGroup().id)}'

// Key Vault resource - only deploy if not in lookup mode
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = if (!lookupOnly) {
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
output keyVaultName string = lookupOnly ? keyVaultName : keyVault.name

@description('The resource ID of the Key Vault')
output keyVaultId string = lookupOnly ? '' : keyVault!.id

@description('The URI of the Key Vault')
output keyVaultUri string = lookupOnly ? '' : keyVault!.properties.vaultUri

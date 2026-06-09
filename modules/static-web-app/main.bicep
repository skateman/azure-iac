// Static Web App (Free tier) for one PWA of the SPA platform.
//
// Generic per-app module: pure static hosting (no repo integration — content is
// pushed by the app's own GitHub Actions using the deploy token). The deploy
// token is written to Key Vault, never emitted as an output.
//
// Custom domains are bound once, out-of-band (see README) — not managed here, so
// this reconciling template never touches them.

@description('App name (used for the static site resource name)')
param appName string

@description('Static Web App control-plane region (content is globally distributed regardless). SWA is not available in every region.')
param location string = 'westeurope'

// Shared Key Vault (same naming convention as the other modules).
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: 'kv-${uniqueString(resourceGroup().id)}'
}

resource staticSite 'Microsoft.Web/staticSites@2024-11-01' = {
  name: 'swa-${appName}'
  location: location
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {
    allowConfigFileUpdates: true
  }
}

// Store the content-deploy token in Key Vault (consumed by the app's deploy workflow).
resource deployTokenSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'swa-${appName}-token'
  properties: {
    value: staticSite.listSecrets().properties.apiKey
  }
}

@description('The default *.azurestaticapps.net hostname — point the custom-domain CNAME at this.')
output defaultHostname string = staticSite.properties.defaultHostname

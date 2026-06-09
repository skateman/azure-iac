// Shared Microsoft Entra app registration backing every PWA on the platform.
// Deploy MANUALLY (your own `az login`), NOT via CI — the GitHub Actions service
// principal intentionally lacks Graph app-management rights. See the README
// ("Shared SPA app registration") for the deploy + secret-setup script.

targetScope = 'resourceGroup'

extension 'br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:1.0.0'

@description('Display / unique name of the shared app registration')
param appName string = 'spa'

@description('Comma-separated app names hosted on the platform.')
param apps string = 'tankstelle'

@description('Domain suffix for the apps.')
param appsDomainSuffix string

@description('Extra redirect URIs (e.g. local dev ports).')
param extraRedirectUris array = [
  'http://localhost:5173'
]

var appRedirectUris = [for app in split(apps, ','): 'https://${app}.${appsDomainSuffix}']
var spaRedirectUris = concat(extraRedirectUris, appRedirectUris)

// guid() keeps the scope id stable across redeploys (avoids recreating the scope).
var accessScopeId = guid(appName, 'access_as_user')

resource spaApp 'Microsoft.Graph/applications@v1.0' = {
  displayName: appName
  uniqueName: appName
  signInAudience: 'AzureADMyOrg'

  spa: {
    redirectUris: spaRedirectUris
  }

  identifierUris: [
    'api://${appName}'
  ]

  api: {
    // v2 access tokens — audience is the application (client) id.
    requestedAccessTokenVersion: 2
    oauth2PermissionScopes: [
      {
        id: accessScopeId
        value: 'access_as_user'
        type: 'User'
        isEnabled: true
        adminConsentDisplayName: 'Access the apps'
        adminConsentDescription: 'Allows a PWA to access its API as the signed-in user.'
        userConsentDisplayName: 'Access the apps'
        userConsentDescription: 'Allows a PWA to access its API on your behalf.'
      }
    ]
  }
}

// Enterprise application (service principal) so users can sign in / consent.
resource spaSp 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: spaApp.appId
  appRoleAssignmentRequired: false
}

@description('Application (client) id (non-secret). The API token audience and the PWA sign-in client id.')
output clientId string = spaApp.appId

@description('Tenant id (ENTRA_TENANT_ID).')
output tenantId string = tenant().tenantId

@description('Scope each PWA requests for an access token.')
output apiScope string = 'api://${appName}/access_as_user'

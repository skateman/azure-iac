# azure-iac [![Deploy](https://github.com/skateman/azure-iac/actions/workflows/deploy.yml/badge.svg)](https://github.com/skateman/azure-iac/actions/workflows/deploy.yml)

Declarative configuration of an Azure resource group with reconciliation.

## Contents
`main.bicep` and `keyvault.bicep` (deployed by CI) describe:
* Key Vault
* Virtual Network - `vnet-bifrost`
* Virtual Machine - `vm-heimdall`
  * With a public IP
  * Exposing WireGuard
* Virtual Machine - `vm-hamlah27`
  * Without a public IP
  * Accessible via `vm-heimdall`
  * Running Home Assistant OS
* Function App - `fn-nexus`
  * Node.js 22 runtime
  * Running functions from https://github.com/skateman/nexus
  * Hosts the SPA platform APIs under `/api/<app>/*`
* Azure OpenAI - `oai`
  * GPT-5.4-nano model with Global deployment
* Azure Speech Services - `speech`
* Static Web Apps - `swa-<app>` (one per app in `apps`)
  * Free tier; hosts each PWA. Custom domain derived as `<app>.<suffix>`
  * Per-app module under `modules/static-web-app`, instantiated in a loop over the `apps` list

`app-registration.bicep` is deployed **manually** (not by CI — see below).

## Setup
First of all, you would need a resource group that ARM/bicep would fully manage. Ideally, this should be empty to avoid collisions with the reconciler.

```sh
az group create --name <rgName> --location <rgLocation>
```

### OIDC for GitHub in Azure
1. Create an application and a service principal:
```sh
az ad app create --display-name "github-oidc-app" --sign-in-audience AzureADMyOrg
az ad sp create --id <appId>
```

2. Create a custom role for accessing the Key Vault for deployment
```sh
az role definition create --role-definition '{
  "Name": "Key Vault Deploy Only",
  "Description": "Allows ARM to resolve Key Vault parameter references during deployment",
  "Actions": [
    "Microsoft.KeyVault/vaults/deploy/action"
  ],
  "AssignableScopes": [
    "/subscriptions/2844d552-9b86-4816-a7b6-32b5ac13512d"
  ]
}'
```

3. Create a custom role for assigning Key Vault access to Managed Identities:
```sh
az role definition create --role-definition '{
  "Name": "Key Vault Access Grantor",
  "Description": "Allows granting Key Vault Secrets User role to Managed Identities only under a Resource Group",
  "Actions": [
    "Microsoft.Authorization/roleAssignments/write",
    "Microsoft.Authorization/roleAssignments/read",
    "Microsoft.Authorization/roleDefinitions/read"
  ],
  "AssignableScopes": [
    "/subscriptions/<subId>/resourceGroups/<rgName>"
  ]
}'
```

3. Create a custom Azure Policy that prevents self-assignment of Key Vault access:
```sh
az policy definition create \
  --name "prevent-github-oidc-self-assignment" \
  --display-name "Prevent GitHub OIDC Self-Assignment" \
  --description "Prevents GitHub OIDC Service Principal from assigning roles to itself" \
  --mode "All" \
  --rules '{
    "if": {
      "allOf": [
        {
          "field": "type",
          "equals": "Microsoft.Authorization/roleAssignments"
        },
        {
          "value": "[requestContext().identity.appid]",
          "equals": "<appId>"
        },
        {
          "field": "Microsoft.Authorization/roleAssignments/principalId",
          "equals": "<appId>"
        }
      ]
    },
    "then": {
      "effect": "deny"
    }
  }'

az policy assignment create --name "no-github-oidc-self-assignment" --policy "prevent-github-oidc-self-assignment" --scope "/subscriptions/<subId>/resourceGroups/<rgName>"
```

4. Assign the Contributor role and the custom roles to the Service Principal:
```sh
az role assignment create --assignee <appId> --role Contributor --scope /subscriptions/<subId>/resourceGroups/<rgName>
az role assignment create --assignee <appId> --role "Key Vault Deploy Only" --scope /subscriptions/<subId>/resourceGroups/<rgName>
az role assignment create --assignee <appId> --role "Key Vault Access Grantor" --scope /subscriptions/<subId>/resourceGroups/<rgName>
```

4. Create federated credentials for GitHub:
```sh
az ad app federated-credential create --id <appId> --parameters '{
  "name": "github-oidc-deploy",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<user>/<repo>:refs/heads/master",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}'
az ad app federated-credential create --id <appId> --parameters '{
  "name": "github-oidc-validate",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<user>/<repo>:pull_request",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}'
```

6. In the repository set the following secrets:
* `AZURE_CLIENT_ID`
* `AZURE_TENANT_ID`
* `AZURE_SUBSCRIPTION_ID`
* `AZURE_RESOURCE_GROUP`

### Key Vault secrets
The pipeline deploys two bicep files after each other. The first step is the creation of a Key Vault defined in `keyvault.bicep` that needs to be manually populated with the following secrets:
* `ssh-public-key`
* `wg-ip-address`
* `wg-private-key`
* `wg-peer-*`
* `spa-client-id`, `owner-oid`, `apps`, `apps-domain-suffix` - see [app-registration script](#shared-spa-app-registration)

As long as the Key Vault does not contain these secrets, the resources defined in the `main.bicep` will fail to deploy. By default, not even the owner of the Resource Group has access to the contents of the Key Vault. Our proposed approach is to create a role that enables the creation but not the reading of secrets and assign it to a user:

1. Create a custom role:
```sh
az role definition create --role-definition '{
  "Name": "Key Vault Secrets Write Only",
  "Description": "Can create, write, and list Key Vault secrets but cannot read secret values",
  "Actions": [],
  "DataActions": [
    "Microsoft.KeyVault/vaults/secrets/setSecret/action",
    "Microsoft.KeyVault/vaults/secrets/readMetadata/action",
    "Microsoft.KeyVault/vaults/secrets/delete"
  ],
  "AssignableScopes": [
    "/subscriptions/2844d552-9b86-4816-a7b6-32b5ac13512d"
  ]
}'
```

2. Assign the custom role to your user:
```sh
az role assignment create --assignee <userId> --role "Key Vault Secrets Write Only" --scope /subscriptions/<subId>/resourceGroups/<rgName>
```

After this your user can populate the Key Vault with the required secrets without being able to read them.

### HAOS base image
The Home Assistant Operating System [image](https://github.com/home-assistant/operating-system/releases) is only published in VHDX format, which is not supported by Azure. Therefore, you have to convert it to fixed-size VHD after unzipping:
```powershell
Convert-VHD -Path "haos_ova-xx.y.vhdx" -DestinationPath "haos.vhd" -VHDType Fixed
```

Unfortunately, uploading the image turned out to be the biggest challenge, the only way it was sucessful was to use the Azure Storage Explorer with the following parameters:
* Disk name: hamlah27
* OS type: Linux
* Availability Zone: None
* Account type: Premium SSD
* Hyper-V generation: V2
* Architecture: x64

It is important that you name the image `hamlah27` as ARM will expect it under this name.

## Shared SPA app registration
`app-registration.bicep` defines a single Microsoft Entra app registration shared by every
PWA on the platform (single-tenant SPA that exposes an `access_as_user` API scope). Redirect
URIs are derived from the `apps` list + the domain suffix; onboard a new app by adding it to
`apps` and redeploying. It is **not** deployed by CI — creating app registrations needs
Microsoft Graph app-management rights, which the GitHub Actions service principal
intentionally does not have.

Deploy it once with your own `az login`. The script below also populates the four
auth/config Key Vault secrets that `main.bicep`:

```sh
# App list + domain suffix -> Key Vault (consumed by main.bicep and the deploy below).
az keyvault secret set --vault-name <kv> --name apps --value <apps>
az keyvault secret set --vault-name <kv> --name apps-domain-suffix --value <suffix>

# Deploy the app registration, capturing its client id straight from the output.
CLIENT_ID=$(az deployment group create \
  --resource-group <rg> \
  --template-file app-registration.bicep \
  --parameters apps=<apps> appsDomainSuffix=<suffix> \
  --query properties.outputs.clientId.value -o tsv)

# Auth identifiers -> Key Vault
az keyvault secret set --vault-name <kv> --name spa-client-id --value "$CLIENT_ID"
az keyvault secret set --vault-name <kv> --name owner-oid \
  --value "$(az ad signed-in-user show --query id -o tsv)"

echo "Set VITE_ENTRA_CLIENT_ID=$CLIENT_ID in the PWA build."
```

Until the `apps`, `apps-domain-suffix`, `spa-client-id` and `owner-oid` secrets exist,
`main.bicep` will not deploy — the same contract as the other Key Vault parameter references
above.

### Onboarding an app / binding custom domains
1. Add the app to the `apps` Key Vault secret (re-run the app-registration script with the
   extended `APPS` list so the redirect URI is added too), then deploy `main.bicep` → its
   `swa-<app>` is created. Read its default `*.azurestaticapps.net` hostname.
2. Add a Namecheap CNAME `<app>.<suffix>` → that default hostname.
3. Bind the custom domain **once** (out-of-band — not in the reconciling template):
   ```sh
   az staticwebapp hostname set --name swa-<app> --hostname <app>.<suffix>
   ```
   The binding persists; the auto-deploying `main.bicep` never touches it (ARM incremental
   mode leaves resources it doesn't declare alone).

`corsAllowedOrigins` and the app registration redirect URIs are derived automatically from
the `apps` list + the suffix, so no per-app edits are needed there.

## Troubleshooting
The VM deployment might fail if you have not accepted the license agreements for the SKU. Unfortunately, this cannot be done via bicep:
```sh
az vm image terms accept --publisher kinvolk --offer flatcar-container-linux-free --plan lts2024-gen2
```

## License
The application is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

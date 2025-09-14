# azure-iac [![Deploy](https://github.com/skateman/azure-iac/actions/workflows/deploy.yml/badge.svg)](https://github.com/skateman/azure-iac/actions/workflows/deploy.yml)

Declarative configuration of an Azure resource group with reconciliation.

## Contents
The two templates in the root directory describe the following resources:
* Key Vault
* Virtual Network - `vnet-bifrost`

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
* TBD ...

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

## License
The application is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

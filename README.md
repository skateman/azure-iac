# azure-iac [![Deploy](https://github.com/skateman/azure-iac/actions/workflows/deploy.yml/badge.svg)](https://github.com/skateman/azure-iac/actions/workflows/deploy.yml)

Declarative configuration of an Azure resource group with reconciliation.

## Contents
The two templates in the root directory describe the following resources:
* Key Vault
* Virtual Network - `vnet-bifrost`

## Setup
First of all, you would need a resource group that ARM/bicep would fully manage. Ideally, this should be empty to avoid collisions with the reconciler.

### OIDC for GitHub in Azure
1. Create an application, a service principal with a Contributor role assigned:
```sh
az ad app create --display-name "github-oidc-app" --sign-in-audience AzureADMyOrg
az ad sp create --id <appId>
az role assignment create --assignee <appId> --role Contributor --scope /subscriptions/<subId>/resourceGroups/<rgName>
```

2. Create a `keyvault-deploy-role.json` file with the custom role definition:
```json
{
  "Name": "Key Vault Deploy Only",
  "Description": "Allows ARM to resolve Key Vault parameter references during deployment",
  "Actions": [
    "Microsoft.KeyVault/vaults/deploy/action"
  ],
  "AssignableScopes": [
    "/subscriptions/2844d552-9b86-4816-a7b6-32b5ac13512d"
  ]
}
```

3. Create the custom role and assign it to the service principal:
```sh
az role definition create --role-definition @keyvault-deploy-role.json
az role assignment create --assignee <appId> --role "Key Vault Deploy Only" --scope /subscriptions/<subId>/resourceGroups/<rgName>
```

4. Create two JSON files that defining federated credentials:
```json
// federated-deploy.json
{
  "name": "github-oidc-deploy",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<user>/<repo>:refs/heads/master",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}

// federated-validate.json
{
  "name": "github-oidc-validate",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:<user>/<repo>:pull_request",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}
```

5. Apply the files against the created application:
```sh
az ad app federated-credential create --id <appId> --parameters @federated-deploy.json
az ad app federated-credential create --id <appId> --parameters @federated-validate.json
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

1. Create the `keyvault-wo-role.json` file with the custom role definition:
```json
{
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
}
```

2. Create the custom role:
```sh
az role definition create --role-definition @keyvault-wo-role.json
```

3. Assign the custom role to your user:
```sh
az role assignment create --assignee <userId> --role "Key Vault Secrets Write Only" --scope /subscriptions/<subId>/resourceGroups/<rgName>
```

After this your user can populate the Key Vault with the required secrets without being able to read them.

## License
The application is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

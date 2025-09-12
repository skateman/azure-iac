# azure-iac
Declarative configuration of an Azure resource group with reconciliation.

## Contents
TBD

## Setup
First of all, you would need a resource group that ARM/bicep would fully manage. Ideally, this should be empty to avoid collisions with the reconciler.

### OIDC for GitHub in Azure
1. Create an application, a service principal with a Contributor role assigned:
```sh
az ad app create --display-name "github-oidc-app" --sign-in-audience AzureADMyOrg
az ad sp create --id <appId>
az role assignment create --assignee <appId> --role Contributor --scope /subscriptions/<subId>/resourceGroups/github-iac
```

2. Create a `keyvault-role.json` file with the custom role definition
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

3. Create the custom role and assign it to the service principal
```sh
az role definition create --role-definition @keyvault-role.json
az role assignment create --assignee <appId> --role "Key Vault Deploy Only" --scope /subscriptions/<subId>/resourceGroups/<rgName>
```

4. Create a `federated.json` file with the repository path
```json
{
  "name": "github-oidc",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "repo:skateman/azure-iac:ref:refs/heads/master",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}
```

5. Apply the file against the created application
```sh
az ad app federated-credential create --id <appId> --parameters @federated.json
```

6. In the repository set the following secrets
* `AZURE_CLIENT_ID`
* `AZURE_TENANT_ID`
* `AZURE_SUBSCRIPTION_ID`
* `AZURE_RESOURCE_GROUP`

## License
The application is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

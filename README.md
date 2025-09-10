# Azure Infrastructure as Code (IaC)

A starter repository for Azure Infrastructure as Code using Bicep templates with automatic deployment via GitHub Actions.

## 🏗️ Repository Structure

```
├── main.bicep              # Main Bicep template
├── parameters/             # Parameter files for different environments
│   ├── dev.json           # Development environment parameters
│   └── prod.json          # Production environment parameters
├── .github/workflows/      # GitHub Actions workflows
│   └── deploy.yml         # Automatic deployment workflow
└── README.md              # This file
```

## 🚀 Getting Started

### Prerequisites

1. **Azure Subscription**: You need an active Azure subscription
2. **Service Principal**: Create a service principal for GitHub Actions authentication
3. **GitHub Repository Secrets**: Configure the required secrets in your repository

### Setting Up Azure Authentication

1. **Create a Service Principal**:
```bash
az ad sp create-for-rbac --name "github-actions-azure-iac" \
  --role contributor \
  --scopes /subscriptions/{subscription-id} \
  --sdk-auth
```

2. **Add the output as a GitHub secret**:
   - Go to your GitHub repository → Settings → Secrets and variables → Actions
   - Create a new secret named `AZURE_CREDENTIALS`
   - Paste the JSON output from the service principal creation

### Environment Configuration

The repository supports multiple environments:

- **Development**: Triggered on pushes to `develop` branch
- **Production**: Triggered on pushes to `main` branch

## 📝 Usage

### Adding Resources

1. Edit `main.bicep` to add your Azure resources
2. Update parameter files in `parameters/` directory as needed
3. Commit and push to trigger automatic deployment

### Example: Adding a Storage Account

Uncomment the storage account example in `main.bicep`:

```bicep
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'st${uniqueString(resourceGroup().id)}'
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}
```

### Local Development

1. **Install Azure CLI**: [Installation Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

2. **Install Bicep CLI**:
```bash
az bicep install
```

3. **Validate templates locally**:
```bash
az bicep build --file main.bicep
```

4. **Deploy manually** (for testing):
```bash
# Login to Azure
az login

# Create resource group
az group create --name rg-azure-iac-dev --location eastus

# Deploy template
az deployment group create \
  --resource-group rg-azure-iac-dev \
  --template-file main.bicep \
  --parameters @parameters/dev.json
```

## 🔄 Automatic Deployment

The repository includes a GitHub Actions workflow that:

1. **Validates** Bicep templates on every push and pull request
2. **Deploys to Development** when pushing to `develop` branch
3. **Deploys to Production** when pushing to `main` branch

### Workflow Features

- ✅ Template validation
- 🔒 Environment protection rules
- 📊 Deployment status reporting
- 🏷️ Proper resource tagging

## 🛠️ Customization

### Environments

To add new environments:

1. Create a new parameter file in `parameters/` (e.g., `test.json`)
2. Update the GitHub Actions workflow to include the new environment
3. Configure environment protection rules in GitHub

### Resource Groups

By default, the deployment creates resource groups named:
- `rg-azure-iac-dev` for development
- `rg-azure-iac-prod` for production

Modify the `AZURE_RESOURCE_GROUP` environment variable in the workflow to change this.

## 📋 Best Practices

1. **Use parameters**: Always parameterize your templates for different environments
2. **Tag resources**: Apply consistent tagging for cost management and organization
3. **Version control**: Keep all infrastructure changes in version control
4. **Review process**: Use pull requests for production changes
5. **Secrets management**: Store sensitive values in GitHub Secrets or Azure Key Vault

## 🔧 Troubleshooting

### Common Issues

1. **Authentication failures**: Verify your `AZURE_CREDENTIALS` secret is correctly formatted
2. **Permission errors**: Ensure your service principal has sufficient permissions
3. **Template validation errors**: Run `az bicep build` locally to check for syntax issues

### Getting Help

- [Azure Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure CLI Documentation](https://docs.microsoft.com/en-us/cli/azure/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
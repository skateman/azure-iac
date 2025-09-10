@description('Name of the resource group')
param resourceGroupName string = 'rg-azure-iac'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Environment name (dev, test, prod)')
param environment string = 'dev'

@description('Tags to apply to all resources')
param tags object = {
  environment: environment
  project: 'azure-iac'
  managedBy: 'bicep'
}

// This is an empty template that creates a resource group
// Add your Azure resources below this comment

// Example: Storage Account (commented out)
/*
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
*/

// Output section for important values
output resourceGroupName string = resourceGroup().name
output location string = location
output environment string = environment
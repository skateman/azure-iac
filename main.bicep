// Main Bicep template for Azure Infrastructure as Code
// This template will orchestrate the deployment of Azure resources
// All resources will be deployed to the target resource group

// Target scope is resource group level
targetScope = 'resourceGroup'

// Metadata
metadata name = 'azure-iac'
metadata description = 'Main Bicep template for declarative Azure resource management'
metadata version = '1.0.0'

// Deploy Bifrost Virtual Network
module bifrostNetwork 'modules/vnet-bifrost/main.bicep' = {
  name: 'vnet-bifrost'
}

// Outputs
@description('The resource group name where resources are deployed')
output resourceGroupName string = resourceGroup().name

@description('The location where resources are deployed')
output deploymentLocation string = resourceGroup().location

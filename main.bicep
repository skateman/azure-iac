// Main Bicep template for Azure Infrastructure as Code
// This template will orchestrate the deployment of Azure resources
// All resources will be deployed to the target resource group

// Target scope is resource group level
targetScope = 'resourceGroup'

// Parameters
@description('SSH public key for VM access')
@secure()
param sshPublicKey string

@description('WireGuard private key')
@secure()
param wgPrivateKey string

@description('WireGuard IP address')
@secure()
param wgIpAddress string

@description('HAOS custom image resource ID for Hamlah27 VM')
param haosImageId string

// Metadata
metadata name = 'azure-iac'
metadata description = 'Main Bicep template for declarative Azure resource management'
metadata version = '1.0.0'

// Deploy Bifrost Virtual Network
module bifrostNetwork 'modules/vnet-bifrost/main.bicep' = {
  name: 'vnet-bifrost'
}

// Deploy Heimdall Virtual Machine
module heimdallVM 'modules/vm-heimdall/main.bicep' = {
  name: 'vm-heimdall'
  params: {
    sshPublicKey: sshPublicKey
    subnetId: bifrostNetwork.outputs.defaultSubnetId
  }
}

// Deploy Hamlah27 Virtual Machine
module hamlah27VM 'modules/vm-hamlah27/main.bicep' = {
  name: 'vm-hamlah27'
  params: {
    subnetId: bifrostNetwork.outputs.defaultSubnetId
    haosImageId: haosImageId
  }
}

// Outputs
@description('The resource group name where resources are deployed')
output resourceGroupName string = resourceGroup().name

@description('The location where resources are deployed')
output deploymentLocation string = resourceGroup().location

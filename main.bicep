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

@description('HAOS custom managed disk resource ID for Hamlah27 VM')
param haosDiskId string

@description('Comma-separated app names hosted on the platform, resolved from Key Vault.')
@secure()
param apps string

@description('Domain suffix for the apps, resolved from Key Vault.')
@secure()
param appsDomainSuffix string

@description('SPA app registration client id')
@secure()
param spaClientId string

@description('Static Web App control-plane region (SWA is not available in every region).')
param swaLocation string = 'westeurope'

// Derived: per-app origins and the CORS allowlist (<app>.<suffix>).
var appList = split(apps, ',')
var corsArray = [for app in appList: 'https://${app}.${appsDomainSuffix}']
var corsAllowedOrigins = join(corsArray, ',')

// Metadata
metadata name = 'azure-iac'
metadata description = 'Main Bicep template for declarative Azure resource management'
metadata version = '1.0.0'

// Deploy Bifrost Virtual Network
module bifrostNetwork 'modules/vnet-bifrost/main.bicep' = {
  name: 'vnet-bifrost'
  params: {
    wgIpAddress: wgIpAddress
  }
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
    haosDiskId: haosDiskId
  }
}

// Azure Open AI
module openAI 'modules/openai/main.bicep' = {
  name: 'oai'
  params: {
    modelName: 'gpt-5.4-nano'
    modelVersion: '2026-03-17'
    capacity: 250
  }
}

// Deploy Nexus Function App
module nexusFunctionApp 'modules/fn-nexus/main.bicep' = {
  name: 'fn-nexus'
  params: {
    sasStart: '2025-12-22T00:00:00Z'
    sasExpiry: '2030-12-31T23:59:59Z'
    gjallarhornSubnetId: bifrostNetwork.outputs.gjallarhornSubnetId
    openAiDeployment: openAI.outputs.deploymentName
    corsAllowedOrigins: corsAllowedOrigins
    spaClientId: spaClientId
  }
}

// Azure Speech Services (TTS/STT)
module speechRoman 'modules/speech/main.bicep' = {
  name: 'speech'
}

// PWA hosting — one Static Web App (Free tier) per app. Custom domains are bound
// once, out-of-band (see README), so they are not managed here.
module appSwas 'modules/static-web-app/main.bicep' = [
  for app in appList: {
    name: 'swa-${app}'
    params: {
      appName: app
      location: swaLocation
    }
  }
]

// Outputs
@description('The resource group name where resources are deployed')
output resourceGroupName string = resourceGroup().name

@description('The location where resources are deployed')
output deploymentLocation string = resourceGroup().location

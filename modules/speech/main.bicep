@description('Location for the Speech resource')
param location string = resourceGroup().location

resource speechService 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: deployment().name
  location: location
  kind: 'SpeechServices'
  sku: {
    name: 'F0' // Free tier: 5h STT + 500K chars TTS per month
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    customSubDomainName: '${deployment().name}-${uniqueString(resourceGroup().id)}'
  }
}

@description('The Speech service endpoint')
output endpoint string = 'https://${speechService.properties.customSubDomainName}.cognitiveservices.azure.com/'

@description('The resource ID')
output resourceId string = speechService.id

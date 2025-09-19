// Virtual Network Bifrost Module
@description('WireGuard IP address/network range')
@secure()
param wgIpAddress string

// Virtual Network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'vnet-bifrost'
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.45.9.0/24'
      ]
    }
    subnets: [
      {
        name: 'snet-bifrost'
        properties: {
          addressPrefix: '10.45.9.0/24' // 10.45.9.1 - 10.45.9.254 (254 usable IPs)
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
}

// Network Security Group for the subnets
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-bifrost'
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'AllowInternalCommunication'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '10.45.9.0/24'
          destinationAddressPrefix: '10.45.9.0/24'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
      {
        name: 'AllowWireGuardClients'
        properties: {
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '${substring(wgIpAddress, 0, lastIndexOf(wgIpAddress, '.'))}.0/24'
          destinationAddressPrefix: '10.45.9.0/24'
          access: 'Allow'
          priority: 1010
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Outputs
@description('The resource ID of the virtual network')
output virtualNetworkId string = virtualNetwork.id

@description('The name of the virtual network')
output virtualNetworkName string = virtualNetwork.name

@description('The resource ID of the default subnet')
output defaultSubnetId string = virtualNetwork.properties.subnets[0].id

@description('The name of the default subnet')
output defaultSubnetName string = virtualNetwork.properties.subnets[0].name

@description('The resource ID of the network security group')
output networkSecurityGroupId string = networkSecurityGroup.id

@description('The address space of the virtual network')
output addressSpace string = virtualNetwork.properties.addressSpace.addressPrefixes[0]

@description('The default subnet address prefix')
output defaultSubnetAddressPrefix string = virtualNetwork.properties.subnets[0].properties.addressPrefix

// Heimdall Virtual Machine Module
@description('The admin username for the virtual machine')
param adminUsername string = 'skateman'

@description('SSH public key for the admin user - retrieved from Key Vault during ARM deployment')
@secure()
param sshPublicKey string

// Public IP for Heimdall
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'pip-heimdall'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
}

// Network Security Group for Heimdall (allows UDP 51820)
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'nsg-heimdall'
  location: resourceGroup().location
  properties: {
    securityRules: [
      {
        name: 'AllowWireGuard'
        properties: {
          protocol: 'UDP'
          sourcePortRange: '*'
          destinationPortRange: '51820'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
        }
      }
    ]
  }
}

// Network Interface for Heimdall
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-heimdall'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.53.6.9'
          subnet: {
            id: 'snet-bifrost'
          }
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
  }
}

// Heimdall Virtual Machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-heimdall'
  location: resourceGroup().location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2ats_v2'
    }
    osProfile: {
      computerName: 'heimdall'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: sshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'kinvolk'
        offer: 'flatcar-container-linux-free'
        sku: 'lts'
        version: '2024'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Delete'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: false
      }
    }
  }
}

// Outputs
@description('The resource ID of the Heimdall virtual machine')
output virtualMachineId string = virtualMachine.id

@description('The name of the Heimdall virtual machine')
output virtualMachineName string = virtualMachine.name

@description('The public IP address of Heimdall')
output publicIPAddress string = publicIP.properties.ipAddress

@description('The private IP address of Heimdall')
output privateIPAddress string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress

@description('The resource ID of the public IP')
output publicIPId string = publicIP.id

@description('The resource ID of the network interface')
output networkInterfaceId string = networkInterface.id

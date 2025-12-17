// Heimdall Virtual Machine Module
@description('Admin username')
param adminUsername string = 'skateman'

@description('SSH public key')
@secure()
param sshPublicKey string

@description('Subnet resource ID for the VM')
param subnetId string

@description('Set to true only when creating the VM for the first time (customData can only be set on initial creation)')
param initialDeploy bool = false

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
          privateIPAddress: '10.45.9.9'
          subnet: {
            id: subnetId
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
  plan: {
    name: 'lts2024-gen2'
    product: 'flatcar-container-linux-free'
    publisher: 'kinvolk'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2ats_v2'
    }
    osProfile: {
      computerName: 'heimdall'
      adminUsername: adminUsername
      customData: initialDeploy ? base64(loadTextContent('ignition.json')) : null
      linuxConfiguration: {
        disablePasswordAuthentication: true
        provisionVMAgent: true
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
        sku: 'lts2024-gen2'
        version: 'latest'
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

// Reference to existing Key Vault (created in main.bicep)
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: 'kv-${uniqueString(resourceGroup().id)}'
}

// Role assignment to grant VM access to Key Vault secrets
resource keyVaultSecretsUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, virtualMachine.id, '4633458b-17de-408a-b874-0445c86b69e6')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: virtualMachine.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Outputs
@description('The resource ID of the Heimdall virtual machine')
output virtualMachineId string = virtualMachine.id

@description('The name of the Heimdall virtual machine')
output virtualMachineName string = virtualMachine.name

@description('The resource ID of the network interface')
output networkInterfaceId string = networkInterface.id

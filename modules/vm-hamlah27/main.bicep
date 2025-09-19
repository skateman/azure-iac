// Hamlah27 Virtual Machine Module
@description('Subnet resource ID for the VM')
param subnetId string

@description('HAOS custom image resource ID')
param haosImageId string

// Network Interface for Hamlah27 (no public IP)
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'nic-hamlah27'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.45.9.27'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

// Hamlah27 Virtual Machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-hamlah27'
  location: resourceGroup().location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2ats_v2'
    }
    osProfile: {
      computerName: 'hamlah27'
    }
    storageProfile: {
      imageReference: {
        id: haosImageId
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
@description('The resource ID of the Hamlah27 virtual machine')
output virtualMachineId string = virtualMachine.id

@description('The name of the Hamlah27 virtual machine')
output virtualMachineName string = virtualMachine.name

@description('The resource ID of the network interface')
output networkInterfaceId string = networkInterface.id

@description('The private IP address of the VM')
output privateIPAddress string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress

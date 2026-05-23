targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Short name used as the prefix for Azure resource names.')
param namePrefix string = 'elk-lab'

@description('Admin username for SSH access.')
param adminUsername string = 'azureuser'

@secure()
@description('SSH public key for the admin user.')
param adminSshPublicKey string

@description('CIDR allowed to SSH to the VM, for example 203.0.113.10/32.')
param sshSourceAddressPrefix string

@description('CIDR allowed to reach the lab HTTP ports. Keep this narrow for test use.')
param labSourceAddressPrefix string = sshSourceAddressPrefix

@description('VM size. Elastic needs more memory than a tiny general-purpose VM.')
param vmSize string = 'Standard_D4s_v5'

@description('OS disk size in GiB.')
param osDiskSizeGB int = 128

@description('Linux image publisher.')
param imagePublisher string = 'almalinux'

@description('Linux image offer.')
param imageOffer string = 'almalinux-x86_64'

@description('Linux image SKU.')
param imageSku string = '9-gen2'

@description('Linux image version.')
param imageVersion string = 'latest'

@description('Cloud-init configuration applied at first boot.')
param customData string = loadTextContent('cloud-init.yaml')

var safePrefix = take(toLower(replace(namePrefix, '_', '-')), 40)
var vnetName = '${safePrefix}-vnet'
var subnetName = 'default'
var nsgName = '${safePrefix}-nsg'
var publicIpName = '${safePrefix}-pip'
var nicName = '${safePrefix}-nic'
var vmName = '${safePrefix}-vm'

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.42.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.42.1.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSsh'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: sshSourceAddressPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowLabHttp'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: [
            '80'
            '5044'
            '5601'
            '9200'
          ]
          sourceAddressPrefix: labSourceAddressPrefix
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      customData: base64(customData)
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminSshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        createOption: 'FromImage'
        diskSizeGB: osDiskSizeGB
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

output adminUsername string = adminUsername
output publicIpAddress string = publicIp.properties.ipAddress
output sshCommand string = 'ssh ${adminUsername}@${publicIp.properties.ipAddress}'
output vmName string = vm.name

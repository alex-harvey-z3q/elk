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

@description('CIDR allowed to reach the lab ingress ports. Keep this narrow for test use.')
param labSourceAddressPrefix string = sshSourceAddressPrefix

@description('VM size. Elastic needs more memory than a tiny general-purpose VM.')
param vmSize string = 'Standard_D4s_v4'

@description('OS disk size in GiB.')
param osDiskSizeGB int = 128

@description('Elasticsearch data disk size in GiB. Attached at LUN 0.')
@minValue(4)
param dataDiskSizeGB int = 128

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'StandardSSD_LRS'
  'StandardSSD_ZRS'
  'Standard_LRS'
])
@description('Managed disk storage type for the Elasticsearch data disk.')
param dataDiskStorageAccountType string = 'Premium_LRS'

@description('Linux image publisher.')
param imagePublisher string = 'almalinux'

@description('Linux image offer.')
param imageOffer string = 'almalinux-x86_64'

@description('Linux image SKU.')
param imageSku string = '9-gen2'

@description('Linux image version.')
param imageVersion string = 'latest'

@description('Cloud-init configuration template applied at first boot.')
param customDataTemplate string = loadTextContent('cloud-init.yaml')

var safePrefix = take(toLower(replace(namePrefix, '_', '-')), 40)
var vnetName = '${safePrefix}-vnet'
var subnetName = 'default'
var nsgName = '${safePrefix}-nsg'
var publicIpName = '${safePrefix}-pip'
var nicName = '${safePrefix}-nic'
var vmName = '${safePrefix}-vm'
var renderedCustomData = replace(customDataTemplate, '__ELK_LAB_SOURCE_CIDR__', labSourceAddressPrefix)

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
        name: 'AllowLabPorts'
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
      customData: base64(renderedCustomData)
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
      dataDisks: [
        {
          lun: 0
          createOption: 'Empty'
          diskSizeGB: dataDiskSizeGB
          managedDisk: {
            storageAccountType: dataDiskStorageAccountType
          }
        }
      ]
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

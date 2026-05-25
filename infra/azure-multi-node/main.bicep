targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string

@description('Short name used as the prefix for Azure resource names.')
param namePrefix string

@description('Admin username for SSH access.')
param adminUsername string

@secure()
@description('SSH public key for the admin user.')
param adminSshPublicKey string

@description('CIDR allowed to SSH to the VMs, for example 203.0.113.10/32.')
param sshSourceAddressPrefix string

@description('Default VM size for non-Elasticsearch nodes.')
param vmSize string

@description('VM size for the Elasticsearch node.')
param elasticsearchVmSize string

@description('OS disk size in GiB.')
param osDiskSizeGB int

@description('Elasticsearch data disk size in GiB. Attached at LUN 0.')
@minValue(4)
param elasticsearchDataDiskSizeGB int

@allowed([
  'Premium_LRS'
  'Premium_ZRS'
  'StandardSSD_LRS'
  'StandardSSD_ZRS'
  'Standard_LRS'
])
@description('Managed disk storage type for the Elasticsearch data disk.')
param dataDiskStorageAccountType string

@description('Linux image publisher.')
param imagePublisher string

@description('Linux image offer.')
param imageOffer string

@description('Linux image SKU.')
param imageSku string

@description('Linux image version.')
param imageVersion string

@description('Cloud-init configuration template applied at first boot.')
param customDataTemplate string

@description('Multi-node lab nodes.')
param nodes array

var safePrefix = take(toLower(replace(namePrefix, '_', '-')), 40)
var vnetName = '${safePrefix}-vnet'
var subnetName = 'default'
var nsgName = '${safePrefix}-nsg'
var vnetAddressPrefix = '10.43.0.0/16'
var subnetAddressPrefix = '10.43.1.0/24'
var allowedInternalPorts = [
  '80'
  '5044'
  '5601'
  '9200'
]

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
        name: 'AllowLabPortsFromClient'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: allowedInternalPorts
          sourceAddressPrefix: sshSourceAddressPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'AllowElasticPortsInsideSubnet'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRanges: allowedInternalPorts
          sourceAddressPrefix: subnetAddressPrefix
          destinationAddressPrefix: subnetAddressPrefix
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource publicIps 'Microsoft.Network/publicIPAddresses@2024-05-01' = [for node in nodes: {
  name: '${safePrefix}-${node.role}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}]

resource nics 'Microsoft.Network/networkInterfaces@2024-05-01' = [for (node, index) in nodes: {
  name: '${safePrefix}-${node.role}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: node.privateIpAddress
          publicIPAddress: {
            id: publicIps[index].id
          }
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2024-07-01' = [for (node, index) in nodes: {
  name: '${safePrefix}-${node.role}-vm'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: node.role == 'elasticsearch' ? elasticsearchVmSize : vmSize
    }
    osProfile: {
      computerName: '${safePrefix}-${node.role}-vm'
      #disable-next-line adminusername-should-not-be-literal
      adminUsername: adminUsername
      customData: base64(replace(replace(customDataTemplate, '__ELK_LAB_SOURCE_CIDR__', sshSourceAddressPrefix), '__ELK_LAB_ROLE__', node.role))
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
      dataDisks: node.hasDataDisk ? [
        {
          lun: 0
          createOption: 'Empty'
          diskSizeGB: elasticsearchDataDiskSizeGB
          managedDisk: {
            storageAccountType: dataDiskStorageAccountType
          }
        }
      ] : []
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[index].id
        }
      ]
    }
  }
}]

output adminUsername string = adminUsername
output nodes array = [for (node, index) in nodes: {
  role: node.role
  vmName: vms[index].name
  privateIpAddress: node.privateIpAddress
  publicIpAddress: publicIps[index].properties.ipAddress
  sshCommand: 'ssh ${adminUsername}@${publicIps[index].properties.ipAddress}'
}]

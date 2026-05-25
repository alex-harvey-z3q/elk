targetScope = 'resourceGroup'

@description('Azure region for all resources.')
param location string

@description('Resource group used by the lab orchestration tasks.')
param resourceGroupName string

@description('Deployment name used by the lab orchestration tasks.')
param deploymentName string

@description('Short name used as the prefix for Azure resource names.')
param namePrefix string

@description('Admin username for SSH access.')
param adminUsername string

@secure()
@description('SSH public key for the admin user.')
param adminSshPublicKey string

@description('CIDR allowed to SSH to the VM, for example 203.0.113.10/32.')
param sshSourceAddressPrefix string

@description('VM size. Elastic needs more memory than a tiny general-purpose VM.')
param vmSize string

@description('OS disk size in GiB.')
param osDiskSizeGB int

@description('Elasticsearch data disk size in GiB. Attached at LUN 0.')
@minValue(4)
param dataDiskSizeGB int

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

@description('Path to the external fact file refreshed by the lab orchestration tasks.')
param sourceFactFile string

@description('Address prefix for the one-node lab virtual network.')
param vnetAddressPrefix string

@description('Address prefix for the one-node lab subnet.')
param subnetAddressPrefix string

var safePrefix = take(toLower(replace(namePrefix, '_', '-')), 40)
var vnetName = '${safePrefix}-vnet'
var subnetName = 'default'
var nsgName = '${safePrefix}-nsg'
var publicIpName = '${safePrefix}-pip'
var nicName = '${safePrefix}-nic'
var vmName = '${safePrefix}-vm'
var renderedCustomData = replace(customDataTemplate, '__ELK_LAB_SOURCE_CIDR__', sshSourceAddressPrefix)

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
          sourceAddressPrefix: sshSourceAddressPrefix
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
      #disable-next-line adminusername-should-not-be-literal
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
output deploymentName string = deploymentName
output publicIpAddress string = publicIp.properties.ipAddress
output resourceGroupName string = resourceGroupName
output sourceFactFile string = sourceFactFile
output sshCommand string = 'ssh ${adminUsername}@${publicIp.properties.ipAddress}'
output vmName string = vm.name

using 'main.bicep'

var adminSshPublicKeyValue = readEnvironmentVariable('AZURE_MULTI_NODE_ADMIN_SSH_PUBLIC_KEY')
var laptopIp = readEnvironmentVariable('LAPTOP_IP')
var laptopIpCidr = '${laptopIp}/32'
param location = 'australiaeast'
param resourceGroupName = 'rg-elk-lab'
param deploymentName = 'elk-multi-node'
param namePrefix = 'elk-lab-multi'
param adminUsername = 'azureuser'
param adminSshPublicKey = adminSshPublicKeyValue
param sshSourceAddressPrefix = laptopIpCidr
param vmSize = 'Standard_D2s_v4'
param elasticsearchVmSize = 'Standard_D4s_v4'
param osDiskSizeGB = 128
param elasticsearchDataDiskSizeGB = 128
param dataDiskStorageAccountType = 'Premium_LRS'
param imagePublisher = 'almalinux'
param imageOffer = 'almalinux-x86_64'
param imageSku = '9-gen2'
param imageVersion = 'latest'
param customDataTemplate = loadTextContent('cloud-init.yaml')
param sourceFactFile = '/etc/facter/facts.d/elk_lab.yaml'
param nodes = [
  {
    role: 'elasticsearch'
    privateIpAddress: '10.43.1.10'
    hasDataDisk: true
  }
  {
    role: 'logstash'
    privateIpAddress: '10.43.1.11'
    hasDataDisk: false
  }
  {
    role: 'kibana'
    privateIpAddress: '10.43.1.12'
    hasDataDisk: false
  }
  {
    role: 'edge'
    privateIpAddress: '10.43.1.13'
    hasDataDisk: false
  }
]

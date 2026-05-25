using 'main.bicep'

var adminSshPublicKeyValue = readEnvironmentVariable('AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY')
var laptopIp = readEnvironmentVariable('LAPTOP_IP')
var laptopIpCidr = '${laptopIp}/32'
param location = 'australiaeast'
param resourceGroupName = 'rg-elk-lab'
param deploymentName = 'elk-one-node'
param namePrefix = 'elk-lab'
param adminUsername = 'azureuser'
param adminSshPublicKey = adminSshPublicKeyValue
param sshSourceAddressPrefix = laptopIpCidr
param vmSize = 'Standard_D4s_v4'
param osDiskSizeGB = 128
param dataDiskSizeGB = 128
param dataDiskStorageAccountType = 'Premium_LRS'
param imagePublisher = 'almalinux'
param imageOffer = 'almalinux-x86_64'
param imageSku = '9-gen2'
param imageVersion = 'latest'
param customDataTemplate = loadTextContent('cloud-init.yaml')
param sourceFactFile = '/etc/facter/facts.d/elk_lab.yaml'

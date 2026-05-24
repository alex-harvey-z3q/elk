using 'main.bicep'

param namePrefix = 'elk-lab'
param location = 'australiaeast'
param adminUsername = 'azureuser'
var adminSshPublicKeyValue = readEnvironmentVariable('AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY')
var laptopIp = readEnvironmentVariable('LAPTOP_IP')
var laptopIpCidr = '${laptopIp}/32'

param adminSshPublicKey = adminSshPublicKeyValue
param sshSourceAddressPrefix = laptopIpCidr
param labSourceAddressPrefix = laptopIpCidr
param vmSize = 'Standard_D4s_v4'
param dataDiskSizeGB = 128

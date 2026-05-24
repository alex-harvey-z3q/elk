using 'main.bicep'

param namePrefix = 'elk-lab'
param location = 'australiaeast'
param adminUsername = 'azureuser'
param adminSshPublicKey = 'ssh-rsa REPLACE_WITH_YOUR_PUBLIC_KEY'
var laptopIp = readEnvironmentVariable('LAPTOP_IP')
var laptopIpCidr = '${laptopIp}/32'

param sshSourceAddressPrefix = laptopIpCidr
param labSourceAddressPrefix = laptopIpCidr
param vmSize = 'Standard_D4s_v4'
param dataDiskSizeGB = 128

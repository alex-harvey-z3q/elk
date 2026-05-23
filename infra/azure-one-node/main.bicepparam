using 'main.bicep'

param namePrefix = 'elk-lab'
param location = 'australiaeast'
param adminUsername = 'azureuser'
param adminSshPublicKey = 'ssh-rsa REPLACE_WITH_YOUR_PUBLIC_KEY'
param sshSourceAddressPrefix = 'REPLACE_WITH_YOUR_PUBLIC_IP/32'
param labSourceAddressPrefix = 'REPLACE_WITH_YOUR_PUBLIC_IP/32'
param dataDiskSizeGB = 128

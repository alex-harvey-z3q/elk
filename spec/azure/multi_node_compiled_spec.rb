require 'json'
require 'ipaddr'
require 'tmpdir'

require 'spec_helper'

RSpec.describe 'compiled multi-node Azure template', :azure_static do
  let(:build_dir) { File.join(Dir.tmpdir, 'elk-azure-multi-node-bicep') }
  let(:template_file) { File.join(build_dir, 'main.json') }
  let(:parameters_file) { File.join(build_dir, 'main.parameters.json') }

  let(:template) { JSON.parse(File.read(template_file)) }
  let(:parameters) { JSON.parse(File.read(parameters_file)) }
  let(:broad_sources) { ['*', '0.0.0.0/0'] }
  let(:roles) { %w[elasticsearch logstash kibana edge] }

  def resources_of_type(template, type)
    template.fetch('resources').select { |resource| resource.fetch('type') == type }
  end

  def only_resource_of_type(template, type)
    resources = resources_of_type(template, type)
    expect(resources.length).to eq(1)
    resources.first
  end

  def security_rule(nsg, name)
    rules = nsg.fetch('properties').fetch('securityRules').select do |rule|
      rule.fetch('name') == name
    end

    expect(rules.length).to eq(1)
    rules.first
  end

  def single_host_ipv4_cidr?(value)
    IPAddr.new(value).ipv4? && value.end_with?('/32')
  rescue IPAddr::InvalidAddressError, TypeError
    false
  end

  def parameter_value(name)
    parameters.fetch('parameters').fetch(name).fetch('value')
  end

  def variable_value(name)
    template.fetch('variables').fetch(name)
  end

  def copy_count(resource)
    resource.fetch('copy').fetch('count')
  end

  it 'defines the expected node roles' do
    expect(parameter_value('nodes').map { |node| node.fetch('role') }).to contain_exactly(*roles)
  end

  it 'creates one VM, NIC, and public IP per node' do
    vm = only_resource_of_type(template, 'Microsoft.Compute/virtualMachines')
    nic = only_resource_of_type(template, 'Microsoft.Network/networkInterfaces')
    public_ip = only_resource_of_type(template, 'Microsoft.Network/publicIPAddresses')

    expect(copy_count(vm)).to eq("[length(parameters('nodes'))]")
    expect(copy_count(nic)).to eq("[length(parameters('nodes'))]")
    expect(copy_count(public_ip)).to eq("[length(parameters('nodes'))]")
    expect(parameter_value('nodes').length).to eq(4)
  end

  it 'creates an Elasticsearch data disk only on the Elasticsearch node' do
    vm = only_resource_of_type(template, 'Microsoft.Compute/virtualMachines')
    data_disks = vm.fetch('properties').fetch('storageProfile').fetch('dataDisks')
    nodes = parameter_value('nodes')

    expect(data_disks).to include("parameters('nodes')[copyIndex()].hasDataDisk")
    expect(data_disks).to include("'lun', 0")
    expect(data_disks).to include("'createOption', 'Empty'")
    expect(nodes.select { |node| node.fetch('hasDataDisk') }.map { |node| node.fetch('role') }).to eq(['elasticsearch'])
  end

  it 'uses static private IP addresses inside the lab subnet' do
    private_ips = parameter_value('nodes').map { |node| node.fetch('privateIpAddress') }

    expect(private_ips).to contain_exactly('10.43.1.10', '10.43.1.11', '10.43.1.12', '10.43.1.13')
  end

  it 'does not allow SSH from a broad public source' do
    nsg = only_resource_of_type(template, 'Microsoft.Network/networkSecurityGroups')
    rule = security_rule(nsg, 'AllowSsh')
    properties = rule.fetch('properties')

    expect(properties.fetch('destinationPortRange')).to eq('22')
    expect(broad_sources).not_to include(properties.fetch('sourceAddressPrefix').to_s)
  end

  it 'keeps client lab ingress narrow and limited to the expected ports' do
    nsg = only_resource_of_type(template, 'Microsoft.Network/networkSecurityGroups')
    rule = security_rule(nsg, 'AllowLabPortsFromClient')
    properties = rule.fetch('properties')

    expect(broad_sources).not_to include(properties.fetch('sourceAddressPrefix').to_s)
    expect(properties.fetch('destinationPortRanges')).to eq("[variables('allowedInternalPorts')]")
    expect(variable_value('allowedInternalPorts')).to contain_exactly('80', '5044', '5601', '9200')
  end

  it 'allows Elastic ports within the lab subnet' do
    nsg = only_resource_of_type(template, 'Microsoft.Network/networkSecurityGroups')
    rule = security_rule(nsg, 'AllowElasticPortsInsideSubnet')
    properties = rule.fetch('properties')

    expect(properties.fetch('sourceAddressPrefix')).to eq("[variables('subnetAddressPrefix')]")
    expect(properties.fetch('destinationAddressPrefix')).to eq("[variables('subnetAddressPrefix')]")
    expect(properties.fetch('destinationPortRanges')).to eq("[variables('allowedInternalPorts')]")
    expect(variable_value('subnetAddressPrefix')).to eq('10.43.1.0/24')
    expect(variable_value('allowedInternalPorts')).to contain_exactly('80', '5044', '5601', '9200')
  end

  it 'uses the LAPTOP_IP-derived single-host CIDR for public ingress' do
    ssh_source = parameter_value('sshSourceAddressPrefix')
    nsg = only_resource_of_type(template, 'Microsoft.Network/networkSecurityGroups')
    ssh_rule = security_rule(nsg, 'AllowSsh')
    lab_rule = security_rule(nsg, 'AllowLabPortsFromClient')

    expect(single_host_ipv4_cidr?(ssh_source)).to eq(true)
    expect(ssh_source).not_to eq('0.0.0.0/0')
    expect(ssh_rule.fetch('properties').fetch('sourceAddressPrefix')).to eq("[parameters('sshSourceAddressPrefix')]")
    expect(lab_rule.fetch('properties').fetch('sourceAddressPrefix')).to eq("[parameters('sshSourceAddressPrefix')]")
  end

  it 'uses an actual SSH public key in the compiled parameters' do
    public_key = parameter_value('adminSshPublicKey')

    expect(public_key).to match(/\Assh-(rsa|ed25519) \S+/)
    expect(public_key).not_to include('REPLACE_WITH_YOUR_PUBLIC_KEY')
  end

  it 'keeps Azure multi-node lab data in the parameter file' do
    expect(parameters.fetch('parameters').keys).to contain_exactly(
      'location',
      'namePrefix',
      'adminUsername',
      'adminSshPublicKey',
      'sshSourceAddressPrefix',
      'vmSize',
      'elasticsearchVmSize',
      'osDiskSizeGB',
      'elasticsearchDataDiskSizeGB',
      'dataDiskStorageAccountType',
      'imagePublisher',
      'imageOffer',
      'imageSku',
      'imageVersion',
      'customDataTemplate',
      'nodes'
    )
    expect(parameter_value('location')).to eq('australiaeast')
    expect(parameter_value('adminUsername')).to eq('azureuser')
    expect(parameter_value('vmSize')).to eq('Standard_D2s_v4')
    expect(parameter_value('elasticsearchVmSize')).to eq('Standard_D4s_v4')
    expect(parameter_value('dataDiskStorageAccountType')).to eq('Premium_LRS')
    expect(parameter_value('imageSku')).to eq('9-gen2')
  end
end

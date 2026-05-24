require 'json'
require 'ipaddr'
require 'tmpdir'

require 'spec_helper'

RSpec.describe 'compiled one-node Azure template', :azure_static do
  let(:build_dir) { File.join(Dir.tmpdir, 'elk-azure-one-node-bicep') }
  let(:template_file) { File.join(build_dir, 'main.json') }
  let(:parameters_file) { File.join(build_dir, 'main.parameters.json') }

  let(:template) { JSON.parse(File.read(template_file)) }
  let(:parameters) { JSON.parse(File.read(parameters_file)) }
  let(:broad_sources) { ['*', '0.0.0.0/0'] }

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

  it 'has a LUN 0 Elasticsearch data disk' do
    vm = only_resource_of_type(template, 'Microsoft.Compute/virtualMachines')
    data_disks = vm.fetch('properties').fetch('storageProfile').fetch('dataDisks')

    expect(data_disks).to include(
      a_hash_including(
        'lun' => 0,
        'createOption' => 'Empty'
      )
    )
  end

  it 'has non-empty customData for cloud-init' do
    vm = only_resource_of_type(template, 'Microsoft.Compute/virtualMachines')
    custom_data = vm.fetch('properties').fetch('osProfile').fetch('customData')

    expect(custom_data).to be_a(String)
    expect(custom_data).not_to be_empty
  end

  it 'does not allow SSH from a broad public source' do
    nsg = only_resource_of_type(template, 'Microsoft.Network/networkSecurityGroups')
    rule = security_rule(nsg, 'AllowSsh')
    properties = rule.fetch('properties')

    expect(properties.fetch('destinationPortRange')).to eq('22')
    expect(broad_sources).not_to include(properties.fetch('sourceAddressPrefix').to_s)
  end

  it 'keeps lab ingress narrow and limited to the expected ports' do
    nsg = only_resource_of_type(template, 'Microsoft.Network/networkSecurityGroups')
    rule = security_rule(nsg, 'AllowLabPorts')
    properties = rule.fetch('properties')

    expect(broad_sources).not_to include(properties.fetch('sourceAddressPrefix').to_s)
    expect(properties.fetch('destinationPortRanges')).to contain_exactly('80', '5044', '5601', '9200')
  end

  it 'uses the LAPTOP_IP-derived single-host CIDR for Azure ingress' do
    ssh_source = parameter_value('sshSourceAddressPrefix')
    nsg = only_resource_of_type(template, 'Microsoft.Network/networkSecurityGroups')
    ssh_rule = security_rule(nsg, 'AllowSsh')
    lab_rule = security_rule(nsg, 'AllowLabPorts')

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

  it 'keeps Azure one-node lab data in the parameter file' do
    expect(parameters.fetch('parameters').keys).to contain_exactly(
      'location',
      'namePrefix',
      'adminUsername',
      'adminSshPublicKey',
      'sshSourceAddressPrefix',
      'vmSize',
      'osDiskSizeGB',
      'dataDiskSizeGB',
      'dataDiskStorageAccountType',
      'imagePublisher',
      'imageOffer',
      'imageSku',
      'imageVersion',
      'customDataTemplate'
    )
    expect(parameter_value('location')).to eq('australiaeast')
    expect(parameter_value('adminUsername')).to eq('azureuser')
    expect(parameter_value('vmSize')).to eq('Standard_D4s_v4')
    expect(parameter_value('dataDiskStorageAccountType')).to eq('Premium_LRS')
    expect(parameter_value('imageSku')).to eq('9-gen2')
  end
end

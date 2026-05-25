require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet_litmus/rake_tasks'
require 'puppet-lint/tasks/puppet-lint'
require 'fileutils'
require 'ipaddr'
require 'json'
require 'open3'
require 'tmpdir'
require 'yaml'

Rake::Task[:lint].clear
PuppetLint.configuration.relative = true
PuppetLint::RakeTask.new(:lint) do |config|
  config.fail_on_warnings = true
  config.disable_checks = [
    'arrow_alignment',
    'arrow_on_right_operand_line',
    'documentation',
    'legacy_facts',
    'variables_not_enclosed',
  ]
  config.ignore_paths = ["tests/**/*.pp", "vendor/**/*.pp","examples/**/*.pp", "spec/**/*.pp", "pkg/**/*.pp"]
end

YAML_LINT_FILES = [
  'spec/fixtures/hiera.yaml',
  'spec/fixtures/hiera.yaml.acceptance',
  'spec/fixtures/hieradata/common.yaml',
  '.github/workflows/ci.yml',
  '.fixtures.yml',
  'infra/azure-one-node/cloud-init.yaml',
  'infra/azure-multi-node/cloud-init.yaml',
].freeze

AZURE_ONE_NODE_TEMPLATE_FILE = 'infra/azure-one-node/main.bicep'
AZURE_ONE_NODE_PARAMETERS_FILE = 'infra/azure-one-node/main.bicepparam'
AZURE_ONE_NODE_CLOUD_INIT_FILE = 'infra/azure-one-node/cloud-init.yaml'
AZURE_ONE_NODE_BUILD_DIR = File.join(Dir.tmpdir, 'elk-azure-one-node-bicep')
AZURE_ONE_NODE_COMPILED_TEMPLATE_FILE = File.join(AZURE_ONE_NODE_BUILD_DIR, 'main.json')
AZURE_ONE_NODE_COMPILED_PARAMETERS_FILE = File.join(AZURE_ONE_NODE_BUILD_DIR, 'main.parameters.json')
AZURE_ONE_NODE_LITMUS_INVENTORY_FILE = 'spec/fixtures/litmus_inventory.yaml'
AZURE_ONE_NODE_PUPPET_COLLECTION = 'puppet8'
AZURE_ONE_NODE_ACCEPTANCE_SPEC = 'spec/acceptance/role_elk_stack_spec.rb'
AZURE_ONE_NODE_PUBLIC_IP_SERVICE = 'https://ifconfig.me'
AZURE_MULTI_NODE_TEMPLATE_FILE = 'infra/azure-multi-node/main.bicep'
AZURE_MULTI_NODE_PARAMETERS_FILE = 'infra/azure-multi-node/main.bicepparam'
AZURE_MULTI_NODE_CLOUD_INIT_FILE = 'infra/azure-multi-node/cloud-init.yaml'
AZURE_MULTI_NODE_BUILD_DIR = File.join(Dir.tmpdir, 'elk-azure-multi-node-bicep')
AZURE_MULTI_NODE_COMPILED_TEMPLATE_FILE = File.join(AZURE_MULTI_NODE_BUILD_DIR, 'main.json')
AZURE_MULTI_NODE_COMPILED_PARAMETERS_FILE = File.join(AZURE_MULTI_NODE_BUILD_DIR, 'main.parameters.json')

desc 'Run yamllint over repository YAML files'
task :yaml_lint do
  sh('yamllint', '-c', 'yamllint.yml', *YAML_LINT_FILES)
end

Rake::Task[:lint].enhance([:yaml_lint])

desc 'Run static checks and unit tests'
task test: [:lint, :spec]

desc 'Prepare fixtures and run unit tests'
task unit: [:spec_prep, :spec]

def ensure_azure_laptop_ip!
  laptop_ip = ENV['LAPTOP_IP'].to_s.strip
  abort <<~MESSAGE if laptop_ip.empty?
    Set LAPTOP_IP before running this task.

    Example:
      export LAPTOP_IP=$(curl -s https://ifconfig.me)
  MESSAGE

  parsed_ip = IPAddr.new(laptop_ip)
  return if parsed_ip.ipv4? && !laptop_ip.include?('/')

  abort <<~MESSAGE
    LAPTOP_IP must be a single IPv4 address without a CIDR suffix.

    Current value:
      LAPTOP_IP=#{laptop_ip}

    Example:
      export LAPTOP_IP=$(curl -s https://ifconfig.me)
  MESSAGE
rescue IPAddr::InvalidAddressError
  abort <<~MESSAGE
    LAPTOP_IP must be a valid IPv4 address.

    Current value:
      LAPTOP_IP=#{laptop_ip}

    Example:
      export LAPTOP_IP=$(curl -s https://ifconfig.me)
  MESSAGE
end

def ensure_azure_admin_ssh_public_key!(env_name)
  public_key = ENV[env_name].to_s.strip
  abort <<~MESSAGE if public_key.empty?
    Set #{env_name} before running this task.

    Example:
      export #{env_name}="$(cat ~/.ssh/id_ed25519.pub)"
  MESSAGE

  return if public_key.match?(/\Assh-(rsa|ed25519) \S+/)

  abort <<~MESSAGE
    #{env_name} must contain an SSH public key.

    Current value:
      #{env_name}=#{public_key}

    Example:
      export #{env_name}="$(cat ~/.ssh/id_ed25519.pub)"
  MESSAGE
end

def ensure_azure_one_node_admin_ssh_public_key!
  ensure_azure_admin_ssh_public_key!('AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY')
end

def ensure_azure_multi_node_admin_ssh_public_key!
  ensure_azure_admin_ssh_public_key!('AZURE_MULTI_NODE_ADMIN_SSH_PUBLIC_KEY')
end

def azure_cli(*args)
  sh(*args)
end

def azure_cli_json(*args)
  stdout, stderr, status = Open3.capture3(*args)
  abort stderr unless status.success?
  JSON.parse(stdout)
end

def capture_command(*args)
  stdout, stderr, status = Open3.capture3(*args)
  abort stderr unless status.success?
  stdout.strip
end

def shell_command(*args)
  sh(*args)
end

def bicepparam_string(file, name)
  pattern = /^\s*(?:param|var)\s+#{Regexp.escape(name)}\s*=\s*'([^']+)'\s*$/
  match = File.read(file).match(pattern)
  abort "Could not find #{name} in #{file}" unless match
  match[1]
end

def azure_resource_group
  bicepparam_string(AZURE_ONE_NODE_PARAMETERS_FILE, 'resourceGroupName')
end

def azure_location
  bicepparam_string(AZURE_ONE_NODE_PARAMETERS_FILE, 'location')
end

def azure_one_node_deployment_name
  bicepparam_string(AZURE_ONE_NODE_PARAMETERS_FILE, 'deploymentName')
end

def azure_multi_node_deployment_name
  bicepparam_string(AZURE_MULTI_NODE_PARAMETERS_FILE, 'deploymentName')
end

def azure_one_node_nsg_name
  "#{bicepparam_string(AZURE_ONE_NODE_PARAMETERS_FILE, 'namePrefix')}-nsg"
end

def azure_multi_node_nsg_name
  "#{bicepparam_string(AZURE_MULTI_NODE_PARAMETERS_FILE, 'namePrefix')}-nsg"
end

def azure_one_node_source_fact_file
  bicepparam_string(AZURE_ONE_NODE_PARAMETERS_FILE, 'sourceFactFile')
end

def azure_multi_node_source_fact_file
  bicepparam_string(AZURE_MULTI_NODE_PARAMETERS_FILE, 'sourceFactFile')
end

def azure_resource_group_exists?
  capture_command('az', 'group', 'exists', '--name', azure_resource_group) == 'true'
end

def wait_for_azure_resource_group_deleted!
  while azure_resource_group_exists?
    puts "Waiting for #{azure_resource_group} to be deleted..."
    sleep 15
  end

  puts "#{azure_resource_group} has been deleted."
end

def destroy_azure_resource_group!(wait: false)
  unless azure_resource_group_exists?
    puts "#{azure_resource_group} does not exist."
    return
  end

  args = [
    'az', 'group', 'delete',
    '--name', azure_resource_group,
    '--yes',
  ]
  args << '--no-wait' unless wait

  azure_cli(*args)
  wait_for_azure_resource_group_deleted! if wait
end

def azure_deployment_outputs(deployment_name)
  azure_cli_json('az', 'deployment', 'group', 'show',
                 '--name', deployment_name,
                 '--resource-group', azure_resource_group,
                 '--query', 'properties.outputs',
                 '--output', 'json')
end

def azure_deployment_output_values(deployment_name)
  azure_deployment_outputs(deployment_name).transform_values { |output| output.fetch('value') }
end

def azure_one_node_outputs
  outputs = azure_deployment_output_values(azure_one_node_deployment_name)

  %w[adminUsername publicIpAddress sshCommand vmName].each do |key|
    next unless outputs[key].to_s.empty?

    abort "Azure one-node output #{key} is missing. Has the one-node VM completed successfully?"
  end

  outputs
end

def print_azure_one_node_outputs(outputs)
  rows = [
    ['AdminUsername', 'PublicIpAddress', 'SshCommand', 'VmName'],
    [
      outputs.fetch('adminUsername'),
      outputs.fetch('publicIpAddress'),
      outputs.fetch('sshCommand'),
      outputs.fetch('vmName'),
    ],
  ]
  widths = rows.transpose.map { |column| column.map(&:length).max }

  puts rows[0].each_with_index.map { |value, index| value.ljust(widths[index]) }.join('  ')
  puts widths.map { |width| '-' * width }.join('  ')
  puts rows[1].each_with_index.map { |value, index| value.ljust(widths[index]) }.join('  ')
end

def azure_multi_node_outputs
  outputs = azure_deployment_outputs(azure_multi_node_deployment_name)
  admin_username = outputs.fetch('adminUsername').fetch('value')

  nodes = outputs.fetch('nodes').fetch('value').map do |node|
    node.merge('adminUsername' => admin_username)
  end

  nodes.each do |node|
    %w[role adminUsername publicIpAddress privateIpAddress sshCommand vmName].each do |key|
      next unless node[key].to_s.empty?

      abort <<~MESSAGE
        Azure multi-node output #{node['role']} #{key} is missing.
        Has the multi-node deployment completed successfully?
      MESSAGE
    end
  end

  nodes
end

def print_azure_multi_node_outputs(nodes)
  rows = [
    ['Role', 'VmName', 'PrivateIpAddress', 'PublicIpAddress', 'SshCommand'],
    *nodes.map do |node|
      [
        node.fetch('role'),
        node.fetch('vmName'),
        node.fetch('privateIpAddress'),
        node.fetch('publicIpAddress'),
        node.fetch('sshCommand'),
      ]
    end,
  ]

  widths = rows.transpose.map { |column| column.map(&:length).max }

  rows.each_with_index do |row, row_index|
    puts row.each_with_index.map { |value, index| value.ljust(widths[index]) }.join('  ')
    puts widths.map { |width| '-' * width }.join('  ') if row_index.zero?
  end
end

def azure_source_cidr
  ensure_azure_laptop_ip!
  "#{ENV['LAPTOP_IP'].strip}/32"
end

def azure_ssh_source_cidr(nsg_name)
  capture_command('az', 'network', 'nsg', 'rule', 'show',
                  '--resource-group', azure_resource_group,
                  '--nsg-name', nsg_name,
                  '--name', 'AllowSsh',
                  '--query', 'sourceAddressPrefix',
                  '--output', 'tsv')
end

def azure_one_node_ssh_source_cidr
  azure_ssh_source_cidr(azure_one_node_nsg_name)
end

def azure_multi_node_ssh_source_cidr
  azure_ssh_source_cidr(azure_multi_node_nsg_name)
end

def current_public_ip
  capture_command('curl', '-s', AZURE_ONE_NODE_PUBLIC_IP_SERVICE)
end

def assert_azure_one_node_source_ip!
  allowed_source = azure_one_node_ssh_source_cidr
  actual_source = "#{current_public_ip}/32"
  return if allowed_source == actual_source

  abort <<~MESSAGE
    Current public IP does not match the Azure one-node SSH allow-list.

    Azure NSG AllowSsh source:
      #{allowed_source}

    Current public IP:
      #{actual_source}

    Update the one-node source IP with the current LAPTOP_IP before running
    acceptance tests:

      export LAPTOP_IP=#{actual_source.delete_suffix('/32')}
      bundle exec rake azure:one_node:update_source_ip
  MESSAGE
end

def assert_azure_multi_node_source_ip!
  allowed_source = azure_multi_node_ssh_source_cidr
  actual_source = "#{current_public_ip}/32"
  return if allowed_source == actual_source

  abort <<~MESSAGE
    Current public IP does not match the Azure multi-node SSH allow-list.

    Azure NSG AllowSsh source:
      #{allowed_source}

    Current public IP:
      #{actual_source}

    Update the multi-node source IP with the current LAPTOP_IP before using
    the deployed VMs:

      export LAPTOP_IP=#{actual_source.delete_suffix('/32')}
      bundle exec rake azure:multi_node:update_source_ip
  MESSAGE
end

def update_azure_nsg_source!(nsg_name, rule_names, source_cidr)
  rule_names.each do |rule_name|
    azure_cli('az', 'network', 'nsg', 'rule', 'update',
              '--resource-group', azure_resource_group,
              '--nsg-name', nsg_name,
              '--name', rule_name,
              '--source-address-prefixes', source_cidr,
              '--output', 'none')
  end
end

def update_azure_one_node_nsg_source!(source_cidr)
  update_azure_nsg_source!(azure_one_node_nsg_name, %w[AllowSsh AllowLabPorts], source_cidr)
end

def azure_vm_run_command!(vm_name, script)
  azure_cli('az', 'vm', 'run-command', 'invoke',
            '--resource-group', azure_resource_group,
            '--name', vm_name,
            '--command-id', 'RunShellScript',
            '--scripts', script,
            '--output', 'none')
end

def update_azure_one_node_fact_source!(outputs, source_cidr)
  script = [
    'mkdir -p /etc/facter/facts.d',
    'espv="$(readlink -f /dev/disk/azure/scsi1/lun0)"',
    "printf '%s\\n' \"espv: ${espv}\" 'elk_lab_source_cidr: #{source_cidr}' > #{azure_one_node_source_fact_file}",
    "chmod 0644 #{azure_one_node_source_fact_file}",
  ].join(' && ')

  azure_vm_run_command!(outputs.fetch('vmName'), script)
end

def update_azure_multi_node_nsg_source!(source_cidr)
  update_azure_nsg_source!(azure_multi_node_nsg_name, %w[AllowSsh AllowLabPortsFromClient], source_cidr)
end

def update_azure_multi_node_fact_source!(nodes, source_cidr)
  nodes.each do |node|
    fact_file = azure_multi_node_source_fact_file
    script = [
      'mkdir -p /etc/facter/facts.d',
      "printf '%s\\n' 'elk_lab_role: #{node.fetch('role')}' 'elk_lab_source_cidr: #{source_cidr}' > #{fact_file}",
      [
        'if [ -e /dev/disk/azure/scsi1/lun0 ]; then',
        'espv="$(readlink -f /dev/disk/azure/scsi1/lun0)";',
        "printf '%s\\n' \"espv: ${espv}\" >> #{fact_file};",
        'fi',
      ].join(' '),
      "chmod 0644 #{fact_file}",
    ].join(' && ')

    azure_vm_run_command!(node.fetch('vmName'), script)
  end
end

def build_azure_bicep!(build_dir:, template_file:, parameters_file:, compiled_template_file:, compiled_parameters_file:)
  FileUtils.mkdir_p(build_dir)
  azure_cli('az', 'bicep', 'build',        '--file', template_file,   '--outfile', compiled_template_file)
  azure_cli('az', 'bicep', 'build-params', '--file', parameters_file, '--outfile', compiled_parameters_file)
end

def validate_azure_deployment!(compiled_template_file, compiled_parameters_file)
  azure_cli('az', 'deployment', 'group', 'validate',
            '--resource-group', azure_resource_group,
            '--template-file', compiled_template_file,
            '--parameters', "@#{compiled_parameters_file}")
end

def create_azure_deployment!(deployment_name, compiled_template_file, compiled_parameters_file)
  azure_cli('az', 'deployment', 'group', 'create',
            '--name', deployment_name,
            '--resource-group', azure_resource_group,
            '--template-file', compiled_template_file,
            '--parameters', "@#{compiled_parameters_file}")
end

def write_azure_one_node_litmus_inventory(outputs)
  inventory = {
    'groups' => [
      {
        'name' => 'ssh_nodes',
        'targets' => [
          {
            'uri' => outputs.fetch('publicIpAddress'),
            'config' => {
              'transport' => 'ssh',
              'ssh' => {
                'user' => outputs.fetch('adminUsername'),
                'run-as' => 'root',
                'host-key-check' => false,
              },
            },
            'facts' => {
              'platform' => 'almalinux-9-x86_64',
              'provisioner' => 'azure',
            },
            'vars' => {
              'role' => 'elk_stack',
              'vm_name' => outputs.fetch('vmName'),
            },
          },
        ],
      },
      {
        'name' => 'winrm_nodes',
        'targets' => [],
      },
    ],
  }

  FileUtils.mkdir_p(File.dirname(AZURE_ONE_NODE_LITMUS_INVENTORY_FILE))
  File.write(AZURE_ONE_NODE_LITMUS_INVENTORY_FILE, YAML.dump(inventory))
  puts "Wrote #{AZURE_ONE_NODE_LITMUS_INVENTORY_FILE} for #{outputs.fetch('publicIpAddress')}"
end

namespace :azure do
  desc 'Create the Azure resource group if it does not already exist'
  task :resource_group do
    azure_cli('az', 'group', 'create', '--name', azure_resource_group, '--location', azure_location)
  end

  desc 'Delete the Azure resource group and all lab resources'
  task :destroy do
    destroy_azure_resource_group!
  end

  namespace :one_node do
    desc 'Lint the one-node Azure Bicep template'
    task :lint do
      azure_cli('az', 'bicep', 'lint', '--file', AZURE_ONE_NODE_TEMPLATE_FILE)
    end

    desc 'Validate the one-node cloud-init configuration schema'
    task :cloud_init_schema do
      shell_command('sudo', 'cloud-init', 'schema', '-c', AZURE_ONE_NODE_CLOUD_INIT_FILE, '--annotate')
    end

    desc 'Compile the one-node Azure Bicep template and parameter file'
    task :build do
      ensure_azure_laptop_ip!
      ensure_azure_one_node_admin_ssh_public_key!
      build_azure_bicep!(
        build_dir: AZURE_ONE_NODE_BUILD_DIR,
        template_file: AZURE_ONE_NODE_TEMPLATE_FILE,
        parameters_file: AZURE_ONE_NODE_PARAMETERS_FILE,
        compiled_template_file: AZURE_ONE_NODE_COMPILED_TEMPLATE_FILE,
        compiled_parameters_file: AZURE_ONE_NODE_COMPILED_PARAMETERS_FILE
      )
    end

    desc 'Assert important properties in the compiled one-node Azure template with RSpec'
    task assert_compiled: [:build] do
      ENV['RUN_AZURE_STATIC_SPECS'] = 'true'
      sh('bundle', 'exec', 'rspec', 'spec/azure/one_node_compiled_spec.rb')
    end

    desc 'Run one-node Azure static checks without deploying resources'
    task static: [:lint, :cloud_init_schema, :assert_compiled]

    desc 'Validate the one-node Azure deployment against the target resource group'
    task validate: [:build] do
      validate_azure_deployment!(
        AZURE_ONE_NODE_COMPILED_TEMPLATE_FILE,
        AZURE_ONE_NODE_COMPILED_PARAMETERS_FILE
      )
    end

    desc 'Deploy the one-node Azure lab VM'
    task deploy: [:build] do
      create_azure_deployment!(
        azure_one_node_deployment_name,
        AZURE_ONE_NODE_COMPILED_TEMPLATE_FILE,
        AZURE_ONE_NODE_COMPILED_PARAMETERS_FILE
      )
    end

    desc 'Show one-node Azure deployment outputs'
    task :outputs do
      print_azure_one_node_outputs(azure_one_node_outputs)
    end

    desc 'Update NSG and VM facts for the current LAPTOP_IP'
    task :update_source_ip do
      source_cidr = azure_source_cidr
      outputs = azure_one_node_outputs

      update_azure_one_node_nsg_source!(source_cidr)
      update_azure_one_node_fact_source!(outputs, source_cidr)
      puts "Updated #{azure_one_node_nsg_name} and #{azure_one_node_source_fact_file} to #{source_cidr}."
    end

    desc 'Write Litmus inventory for the deployed one-node Azure VM'
    task :inventory do
      write_azure_one_node_litmus_inventory(azure_one_node_outputs)
    end

    desc 'Check current public IP against the Azure one-node SSH allow-list'
    task :source_ip do
      assert_azure_one_node_source_ip!
      puts "Current public IP matches #{azure_one_node_nsg_name} AllowSsh."
    end

    desc 'Check Litmus SSH connectivity to the deployed one-node Azure VM'
    task check_connectivity: [:inventory] do
      target_host = azure_one_node_outputs.fetch('publicIpAddress')
      Rake::Task['litmus:check_connectivity'].invoke(target_host)
    end

    desc 'Install the Puppet agent on the deployed one-node Azure VM'
    task install_agent: [:check_connectivity] do
      target_host = azure_one_node_outputs.fetch('publicIpAddress')
      Rake::Task['litmus:install_agent'].invoke(AZURE_ONE_NODE_PUPPET_COLLECTION, target_host)
    end

    desc 'Run acceptance tests against the deployed one-node Azure VM'
    task acceptance: [:install_agent] do
      target_host = azure_one_node_outputs.fetch('publicIpAddress')
      env = { 'TARGET_HOST' => target_host }
      sh(env, 'bundle', 'exec', 'rspec', AZURE_ONE_NODE_ACCEPTANCE_SPEC)
    end

    desc 'Create, test, and destroy the one-node Azure VM'
    task :acceptance_ephemeral do
      begin
        Rake::Task['azure:resource_group'].invoke
        Rake::Task['azure:one_node:validate'].invoke
        Rake::Task['azure:one_node:deploy'].invoke
        Rake::Task['azure:one_node:acceptance'].invoke
      ensure
        destroy_azure_resource_group!(wait: true)
      end
    end
  end

  namespace :multi_node do
    desc 'Lint the multi-node Azure Bicep template'
    task :lint do
      azure_cli('az', 'bicep', 'lint', '--file', AZURE_MULTI_NODE_TEMPLATE_FILE)
    end

    desc 'Validate the multi-node cloud-init configuration schema'
    task :cloud_init_schema do
      shell_command('sudo', 'cloud-init', 'schema', '-c', AZURE_MULTI_NODE_CLOUD_INIT_FILE, '--annotate')
    end

    desc 'Compile the multi-node Azure Bicep template and parameter file'
    task :build do
      ensure_azure_laptop_ip!
      ensure_azure_multi_node_admin_ssh_public_key!
      build_azure_bicep!(
        build_dir: AZURE_MULTI_NODE_BUILD_DIR,
        template_file: AZURE_MULTI_NODE_TEMPLATE_FILE,
        parameters_file: AZURE_MULTI_NODE_PARAMETERS_FILE,
        compiled_template_file: AZURE_MULTI_NODE_COMPILED_TEMPLATE_FILE,
        compiled_parameters_file: AZURE_MULTI_NODE_COMPILED_PARAMETERS_FILE
      )
    end

    desc 'Assert important properties in the compiled multi-node Azure template with RSpec'
    task assert_compiled: [:build] do
      ENV['RUN_AZURE_STATIC_SPECS'] = 'true'
      sh('bundle', 'exec', 'rspec', 'spec/azure/multi_node_compiled_spec.rb')
    end

    desc 'Run multi-node Azure static checks without deploying resources'
    task static: [:lint, :cloud_init_schema, :assert_compiled]

    desc 'Validate the multi-node Azure deployment against the target resource group'
    task validate: [:build] do
      validate_azure_deployment!(
        AZURE_MULTI_NODE_COMPILED_TEMPLATE_FILE,
        AZURE_MULTI_NODE_COMPILED_PARAMETERS_FILE
      )
    end

    desc 'Deploy the multi-node Azure lab VMs'
    task deploy: [:build] do
      create_azure_deployment!(
        azure_multi_node_deployment_name,
        AZURE_MULTI_NODE_COMPILED_TEMPLATE_FILE,
        AZURE_MULTI_NODE_COMPILED_PARAMETERS_FILE
      )
    end

    desc 'Show multi-node Azure deployment outputs'
    task :outputs do
      print_azure_multi_node_outputs(azure_multi_node_outputs)
    end

    desc 'Update NSG and VM facts for the current LAPTOP_IP'
    task :update_source_ip do
      source_cidr = azure_source_cidr
      nodes = azure_multi_node_outputs
      update_azure_multi_node_nsg_source!(source_cidr)
      update_azure_multi_node_fact_source!(nodes, source_cidr)
      puts "Updated #{azure_multi_node_nsg_name} and #{azure_multi_node_source_fact_file} to #{source_cidr}."
    end

    desc 'Check current public IP against the Azure multi-node SSH allow-list'
    task :source_ip do
      assert_azure_multi_node_source_ip!
      puts "Current public IP matches #{azure_multi_node_nsg_name} AllowSsh."
    end
  end
end

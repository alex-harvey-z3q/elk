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
].freeze

AZURE_RESOURCE_GROUP = 'rg-elk-lab'
AZURE_LOCATION = 'australiaeast'
AZURE_ONE_NODE_TEMPLATE_FILE = 'infra/azure-one-node/main.bicep'
AZURE_ONE_NODE_PARAMETERS_FILE = 'infra/azure-one-node/main.bicepparam'
AZURE_ONE_NODE_CLOUD_INIT_FILE = 'infra/azure-one-node/cloud-init.yaml'
AZURE_ONE_NODE_DEPLOYMENT_NAME = 'elk-one-node'
AZURE_ONE_NODE_NSG_NAME = 'elk-lab-nsg'
AZURE_ONE_NODE_PUBLIC_IP_NAME = 'elk-lab-pip'
AZURE_ONE_NODE_SOURCE_FACT_FILE = '/etc/facter/facts.d/elk_lab.yaml'
AZURE_ONE_NODE_VM_NAME = 'elk-lab-vm'
AZURE_ONE_NODE_BUILD_DIR = File.join(Dir.tmpdir, 'elk-azure-one-node-bicep')
AZURE_ONE_NODE_COMPILED_TEMPLATE_FILE = File.join(AZURE_ONE_NODE_BUILD_DIR, 'main.json')
AZURE_ONE_NODE_COMPILED_PARAMETERS_FILE = File.join(AZURE_ONE_NODE_BUILD_DIR, 'main.parameters.json')
AZURE_ONE_NODE_LITMUS_INVENTORY_FILE = 'spec/fixtures/litmus_inventory.yaml'
AZURE_ONE_NODE_PUPPET_COLLECTION = 'puppet8'
AZURE_ONE_NODE_ACCEPTANCE_SPEC = 'spec/acceptance/role_elk_stack_spec.rb'
AZURE_ONE_NODE_PUBLIC_IP_SERVICE = 'https://ifconfig.me'

desc 'Run yamllint over repository YAML files'
task :yaml_lint do
  sh('yamllint', '-c', 'yamllint.yml', *YAML_LINT_FILES)
end

Rake::Task[:lint].enhance([:yaml_lint])

desc 'Run static checks and unit tests'
task test: [:lint, :spec]

desc 'Prepare fixtures and run unit tests'
task unit: [:spec_prep, :spec]

def ensure_azure_one_node_laptop_ip!
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

def ensure_azure_one_node_admin_ssh_public_key!
  public_key = ENV['AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY'].to_s.strip
  abort <<~MESSAGE if public_key.empty?
    Set AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY before running this task.

    Example:
      export AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
  MESSAGE

  return if public_key.match?(/\Assh-(rsa|ed25519) \S+/)

  abort <<~MESSAGE
    AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY must contain an SSH public key.

    Current value:
      AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY=#{public_key}

    Example:
      export AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
  MESSAGE
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

def azure_resource_group_exists?
  capture_command(
    'az', 'group', 'exists',
    '--name', AZURE_RESOURCE_GROUP
  ) == 'true'
end

def wait_for_azure_resource_group_deleted!
  while azure_resource_group_exists?
    puts "Waiting for #{AZURE_RESOURCE_GROUP} to be deleted..."
    sleep 15
  end

  puts "#{AZURE_RESOURCE_GROUP} has been deleted."
end

def destroy_azure_resource_group!(wait: false)
  unless azure_resource_group_exists?
    puts "#{AZURE_RESOURCE_GROUP} does not exist."
    return
  end

  args = [
    'az', 'group', 'delete',
    '--name', AZURE_RESOURCE_GROUP,
    '--yes',
  ]
  args << '--no-wait' unless wait

  azure_cli(*args)
  wait_for_azure_resource_group_deleted! if wait
end

def azure_one_node_outputs
  admin_username = capture_command(
    'az', 'vm', 'show',
    '--resource-group', AZURE_RESOURCE_GROUP,
    '--name', AZURE_ONE_NODE_VM_NAME,
    '--query', 'osProfile.adminUsername',
    '--output', 'tsv'
  )
  public_ip_address = capture_command(
    'az', 'network', 'public-ip', 'show',
    '--resource-group', AZURE_RESOURCE_GROUP,
    '--name', AZURE_ONE_NODE_PUBLIC_IP_NAME,
    '--query', 'ipAddress',
    '--output', 'tsv'
  )

  outputs = {
    'adminUsername' => admin_username,
    'publicIpAddress' => public_ip_address,
    'sshCommand' => "ssh #{admin_username}@#{public_ip_address}",
    'vmName' => AZURE_ONE_NODE_VM_NAME,
  }

  %w[adminUsername publicIpAddress sshCommand vmName].each do |key|
    abort "Azure one-node output #{key} is missing. Has the one-node VM completed successfully?" if outputs[key].to_s.empty?
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

def azure_one_node_source_cidr
  ensure_azure_one_node_laptop_ip!

  "#{ENV['LAPTOP_IP'].strip}/32"
end

def azure_one_node_ssh_source_cidr
  capture_command(
    'az', 'network', 'nsg', 'rule', 'show',
    '--resource-group', AZURE_RESOURCE_GROUP,
    '--nsg-name', AZURE_ONE_NODE_NSG_NAME,
    '--name', 'AllowSsh',
    '--query', 'sourceAddressPrefix',
    '--output', 'tsv'
  )
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

def update_azure_one_node_nsg_source!(source_cidr)
  %w[AllowSsh AllowLabPorts].each do |rule_name|
    azure_cli(
      'az', 'network', 'nsg', 'rule', 'update',
      '--resource-group', AZURE_RESOURCE_GROUP,
      '--nsg-name', AZURE_ONE_NODE_NSG_NAME,
      '--name', rule_name,
      '--source-address-prefixes', source_cidr,
      '--output', 'none'
    )
  end
end

def update_azure_one_node_fact_source!(outputs, source_cidr)
  script = [
    'mkdir -p /etc/facter/facts.d',
    'espv="$(readlink -f /dev/disk/azure/scsi1/lun0)"',
    "printf '%s\\n' \"espv: ${espv}\" 'elk_lab_source_cidr: #{source_cidr}' > #{AZURE_ONE_NODE_SOURCE_FACT_FILE}",
    "chmod 0644 #{AZURE_ONE_NODE_SOURCE_FACT_FILE}",
  ].join(' && ')

  azure_cli(
    'az', 'vm', 'run-command', 'invoke',
    '--resource-group', AZURE_RESOURCE_GROUP,
    '--name', outputs.fetch('vmName'),
    '--command-id', 'RunShellScript',
    '--scripts', script,
    '--output', 'none'
  )
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
    azure_cli(
      'az', 'group', 'create',
      '--name', AZURE_RESOURCE_GROUP,
      '--location', AZURE_LOCATION
    )
  end

  desc 'Delete the Azure resource group and all lab resources'
  task :destroy do
    destroy_azure_resource_group!
  end

  namespace :one_node do
    desc 'Lint the one-node Azure Bicep template'
    task :lint do
      azure_cli(
        'az', 'bicep', 'lint',
        '--file', AZURE_ONE_NODE_TEMPLATE_FILE
      )
    end

    desc 'Validate the one-node cloud-init configuration schema'
    task :cloud_init_schema do
      shell_command(
        'sudo',
        'cloud-init', 'schema',
        '-c', AZURE_ONE_NODE_CLOUD_INIT_FILE,
        '--annotate'
      )
    end

    desc 'Compile the one-node Azure Bicep template and parameter file'
    task :build do
      ensure_azure_one_node_laptop_ip!
      ensure_azure_one_node_admin_ssh_public_key!
      FileUtils.mkdir_p(AZURE_ONE_NODE_BUILD_DIR)
      azure_cli(
        'az', 'bicep', 'build',
        '--file', AZURE_ONE_NODE_TEMPLATE_FILE,
        '--outfile', AZURE_ONE_NODE_COMPILED_TEMPLATE_FILE
      )
      azure_cli(
        'az', 'bicep', 'build-params',
        '--file', AZURE_ONE_NODE_PARAMETERS_FILE,
        '--outfile', AZURE_ONE_NODE_COMPILED_PARAMETERS_FILE
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
      azure_cli(
        'az', 'deployment', 'group', 'validate',
        '--resource-group', AZURE_RESOURCE_GROUP,
        '--template-file', AZURE_ONE_NODE_COMPILED_TEMPLATE_FILE,
        '--parameters', "@#{AZURE_ONE_NODE_COMPILED_PARAMETERS_FILE}"
      )
    end

    desc 'Deploy the one-node Azure lab VM'
    task deploy: [:build] do
      azure_cli(
        'az', 'deployment', 'group', 'create',
        '--name', AZURE_ONE_NODE_DEPLOYMENT_NAME,
        '--resource-group', AZURE_RESOURCE_GROUP,
        '--template-file', AZURE_ONE_NODE_COMPILED_TEMPLATE_FILE,
        '--parameters', "@#{AZURE_ONE_NODE_COMPILED_PARAMETERS_FILE}"
      )
    end

    desc 'Show one-node Azure deployment outputs'
    task :outputs do
      print_azure_one_node_outputs(azure_one_node_outputs)
    end

    desc 'Update NSG and VM facts for the current LAPTOP_IP'
    task :update_source_ip do
      source_cidr = azure_one_node_source_cidr
      outputs = azure_one_node_outputs

      update_azure_one_node_nsg_source!(source_cidr)
      update_azure_one_node_fact_source!(outputs, source_cidr)
      puts "Updated #{AZURE_ONE_NODE_NSG_NAME} and #{AZURE_ONE_NODE_SOURCE_FACT_FILE} to #{source_cidr}."
    end

    desc 'Write Litmus inventory for the deployed one-node Azure VM'
    task :inventory do
      write_azure_one_node_litmus_inventory(azure_one_node_outputs)
    end

    desc 'Check current public IP against the Azure one-node SSH allow-list'
    task :source_ip do
      assert_azure_one_node_source_ip!
      puts "Current public IP matches #{AZURE_ONE_NODE_NSG_NAME} AllowSsh."
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
end

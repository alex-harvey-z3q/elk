require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet_litmus/rake_tasks'
require 'puppet-lint/tasks/puppet-lint'
require 'fileutils'
require 'ipaddr'
require 'tmpdir'

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

desc 'Run yamllint over repository YAML files'
task :yaml_lint do
  sh('yamllint', '-c', 'yamllint.yml', *YAML_LINT_FILES)
end

Rake::Task[:lint].enhance([:yaml_lint])

desc 'Run static checks and unit tests'
task test: [:lint, :spec]

desc 'Prepare fixtures and run unit tests'
task :unit do
  Rake::Task[:spec_prep].invoke
  Rake::Task[:spec].invoke
end

def azure_resource_group
  ENV.fetch('AZURE_RESOURCE_GROUP', 'rg-elk-lab')
end

def azure_location
  ENV.fetch('AZURE_LOCATION', 'australiaeast')
end

def azure_one_node_template_file
  ENV.fetch('AZURE_ONE_NODE_TEMPLATE_FILE', 'infra/azure-one-node/main.bicep')
end

def azure_one_node_parameters_file
  ENV.fetch('AZURE_ONE_NODE_PARAMETERS_FILE', 'infra/azure-one-node/main.bicepparam')
end

def azure_one_node_admin_ssh_public_key_files
  explicit_public_key_file = ENV['AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY_FILE']
  abort <<~MESSAGE if explicit_public_key_file && !File.file?(explicit_public_key_file)
    AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY_FILE does not point to a readable public key file.

    Current value:
      AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY_FILE=#{explicit_public_key_file}

    Example:
      export AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY_FILE=~/.ssh/id_ed25519.pub
  MESSAGE

  [
    explicit_public_key_file,
    File.expand_path('~/.ssh/id_ed25519.pub'),
    File.expand_path('~/.ssh/id_rsa.pub'),
  ].compact
end

def ensure_azure_one_node_laptop_ip!
  laptop_ip = ENV.fetch('LAPTOP_IP', '').strip
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
  return unless ENV.fetch('AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY', '').strip.empty?

  public_key_file = azure_one_node_admin_ssh_public_key_files.find { |path| File.file?(path) }
  abort <<~MESSAGE if public_key_file.nil?
    Set AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY or AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY_FILE before running this task.

    Examples:
      export AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
      export AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY_FILE=~/.ssh/id_ed25519.pub
  MESSAGE

  public_key = File.read(public_key_file).strip
  abort <<~MESSAGE if public_key.empty?
    SSH public key file #{public_key_file} is empty.

    Set a different public key file:
      export AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY_FILE=~/.ssh/id_ed25519.pub
  MESSAGE

  ENV['AZURE_ONE_NODE_ADMIN_SSH_PUBLIC_KEY'] = public_key
end

def azure_one_node_cloud_init_file
  ENV.fetch('AZURE_ONE_NODE_CLOUD_INIT_FILE', 'infra/azure-one-node/cloud-init.yaml')
end

def azure_one_node_deployment_name
  ENV.fetch('AZURE_ONE_NODE_DEPLOYMENT_NAME', 'elk-one-node')
end

def azure_one_node_build_dir
  ENV.fetch('AZURE_ONE_NODE_BUILD_DIR', File.join(Dir.tmpdir, 'elk-azure-one-node-bicep'))
end

def azure_one_node_compiled_template_file
  File.join(azure_one_node_build_dir, 'main.json')
end

def azure_one_node_compiled_parameters_file
  File.join(azure_one_node_build_dir, 'main.parameters.json')
end

def azure_cli(*args)
  sh(*args)
end

def shell_command(*args)
  sh(*args)
end

namespace :azure do
  desc 'Create the Azure resource group if it does not already exist'
  task :resource_group do
    azure_cli(
      'az', 'group', 'create',
      '--name', azure_resource_group,
      '--location', azure_location
    )
  end

  desc 'Delete the Azure resource group and all lab resources'
  task :destroy do
    azure_cli(
      'az', 'group', 'delete',
      '--name', azure_resource_group,
      '--yes',
      '--no-wait'
    )
  end

  namespace :one_node do
    desc 'Lint the one-node Azure Bicep template'
    task :lint do
      azure_cli(
        'az', 'bicep', 'lint',
        '--file', azure_one_node_template_file
      )
    end

    desc 'Validate the one-node cloud-init configuration schema'
    task :cloud_init_schema do
      shell_command(
        'sudo',
        'cloud-init', 'schema',
        '-c', azure_one_node_cloud_init_file,
        '--annotate'
      )
    end

    desc 'Compile the one-node Azure Bicep template and parameter file'
    task :build do
      ensure_azure_one_node_laptop_ip!
      ensure_azure_one_node_admin_ssh_public_key!
      FileUtils.mkdir_p(azure_one_node_build_dir)
      azure_cli(
        'az', 'bicep', 'build',
        '--file', azure_one_node_template_file,
        '--outfile', azure_one_node_compiled_template_file
      )
      azure_cli(
        'az', 'bicep', 'build-params',
        '--file', azure_one_node_parameters_file,
        '--outfile', azure_one_node_compiled_parameters_file
      )
    end

    desc 'Assert important properties in the compiled one-node Azure template with RSpec'
    task assert_compiled: [:build] do
      ENV['RUN_AZURE_STATIC_SPECS'] = 'true'
      ENV['AZURE_ONE_NODE_COMPILED_TEMPLATE_FILE'] = azure_one_node_compiled_template_file
      ENV['AZURE_ONE_NODE_COMPILED_PARAMETERS_FILE'] = azure_one_node_compiled_parameters_file
      sh('bundle', 'exec', 'rspec', 'spec/azure/one_node_compiled_spec.rb')
    end

    desc 'Run one-node Azure static checks without deploying resources'
    task static: [:lint, :cloud_init_schema, :assert_compiled]

    desc 'Validate the one-node Azure deployment against the target resource group'
    task validate: [:build] do
      azure_cli(
        'az', 'deployment', 'group', 'validate',
        '--resource-group', azure_resource_group,
        '--template-file', azure_one_node_compiled_template_file,
        '--parameters', "@#{azure_one_node_compiled_parameters_file}"
      )
    end

    desc 'Deploy the one-node Azure lab VM'
    task deploy: [:build] do
      azure_cli(
        'az', 'deployment', 'group', 'create',
        '--name', azure_one_node_deployment_name,
        '--resource-group', azure_resource_group,
        '--template-file', azure_one_node_compiled_template_file,
        '--parameters', "@#{azure_one_node_compiled_parameters_file}"
      )
    end

    desc 'Show one-node Azure deployment outputs'
    task :outputs do
      azure_cli(
        'az', 'deployment', 'group', 'show',
        '--name', azure_one_node_deployment_name,
        '--resource-group', azure_resource_group,
        '--query', 'properties.outputs',
        '--output', 'table'
      )
    end
  end
end

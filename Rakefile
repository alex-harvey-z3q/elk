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

AZURE_RESOURCE_GROUP = 'rg-elk-lab'
AZURE_LOCATION = 'australiaeast'
AZURE_ONE_NODE_TEMPLATE_FILE = 'infra/azure-one-node/main.bicep'
AZURE_ONE_NODE_PARAMETERS_FILE = 'infra/azure-one-node/main.bicepparam'
AZURE_ONE_NODE_CLOUD_INIT_FILE = 'infra/azure-one-node/cloud-init.yaml'
AZURE_ONE_NODE_DEPLOYMENT_NAME = 'elk-one-node'
AZURE_ONE_NODE_BUILD_DIR = File.join(Dir.tmpdir, 'elk-azure-one-node-bicep')
AZURE_ONE_NODE_COMPILED_TEMPLATE_FILE = File.join(AZURE_ONE_NODE_BUILD_DIR, 'main.json')
AZURE_ONE_NODE_COMPILED_PARAMETERS_FILE = File.join(AZURE_ONE_NODE_BUILD_DIR, 'main.parameters.json')

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

def shell_command(*args)
  sh(*args)
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
    azure_cli(
      'az', 'group', 'delete',
      '--name', AZURE_RESOURCE_GROUP,
      '--yes',
      '--no-wait'
    )
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
      azure_cli(
        'az', 'deployment', 'group', 'show',
        '--name', AZURE_ONE_NODE_DEPLOYMENT_NAME,
        '--resource-group', AZURE_RESOURCE_GROUP,
        '--query', 'properties.outputs',
        '--output', 'table'
      )
    end
  end
end

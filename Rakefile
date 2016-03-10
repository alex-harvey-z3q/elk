require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-lint/tasks/puppet-lint'

Rake::Task[:lint].clear
PuppetLint.configuration.relative = true
PuppetLint::RakeTask.new(:lint) do |config|
  config.fail_on_warnings = true
  config.disable_checks = [
    'class_inherits_from_params_class',
    'class_parameter_defaults',
    'documentation',
    'single_quote_string_with_variables',
    'variables_not_enclosed',
    'arrow_alignment',
  ]
  config.ignore_paths = ["tests/**/*.pp", "vendor/**/*.pp","examples/**/*.pp", "spec/**/*.pp", "pkg/**/*.pp"]
end
require 'puppetlabs_spec_helper/rake_tasks'

def run(command)
  puts "Running #{command}"
  status = system(command)
  return status
end

desc 'Install puppet modules with librarian-puppet'
task :librarian_spec_prep do
  raise "librarian_spec_prep called but NO_LIBRARIAN set" if ENV['NO_LIBRARIAN']
  location = ENV['LOCATION'] || 'spec/fixtures'
  if librarian_puppet_tmp = ENV['LIBRARIAN_PUPPET_TMP']
    command = "cd #{location} && LIBRARIAN_PUPPET_TMP=#{librarian_puppet_tmp} bundle exec librarian-puppet install"
  else
    command = "cd #{location} && bundle exec librarian-puppet install"
  end
  status = run(command)
  raise "libarian-puppet-install exited non-zero" unless status
end

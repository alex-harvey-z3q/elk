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

def location
  ENV['LOCATION'] || 'spec/fixtures'
end

def run(command)
  puts "Running #{command}"
  begin
    system(command)
  rescue => e
    raise "#{command} failed: #{e}"
  end
end

desc 'Install puppet modules with librarian-puppet'
task :librarian_spec_prep do
  command = "cd #{location} "
  if ENV['LIBRARIAN_PUPPET_TMP']
    command += "&& LIBRARIAN_PUPPET_TMP=#{ENV['LIBRARIAN_PUPPET_TMP']} "
  else
    command += '&& '
  end
  command += "bundle exec librarian-puppet install #{ENV['LIBRARIAN_VERBOSE']}"
  run command
end

desc 'Update puppet modules with librarian-puppet'
task :librarian_update do
  system('rm -f spec/fixtures/Puppetfile.lock')
  command = "cd #{location} "
  if ENV['LIBRARIAN_PUPPET_TMP']
    command += "&& LIBRARIAN_PUPPET_TMP=#{ENV['LIBRARIAN_PUPPET_TMP']} "
  else
    command += '&& '
  end
  command += "bundle exec librarian-puppet update #{ENV['LIBRARIAN_VERBOSE']}"
  run command
end

desc "Run spec tests using librarian-puppet to checkout modules"
task :librarian_spec do
  Rake::Task[:librarian_spec_prep].invoke
  Rake::Task[:spec_prep].invoke
  Rake::Task[:spec_standalone].invoke
  Rake::Task[:spec_clean].invoke
end

# Environment variables:
#
#   NO_G10K, NO_LIBRARIAN, NO_CHECKOUT - all have the same effect of preventing
#     librarian or g10k from installing the modules from the Forge.
#
#   LIBRARIAN_VERBOSE - pass --verbose to librarian-puppet.
#
#   FORCE_LIBRARIAN - use librarian-puppet even if g10k is available.
#
require 'puppetlabs_spec_helper/rake_tasks'
require 'puppet-lint/tasks/puppet-lint'
require 'versionomy'
require 'puppet/version'

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
    'arrow_on_right_operand_line',
  ]
  config.ignore_paths = ["tests/**/*.pp", "vendor/**/*.pp","examples/**/*.pp", "spec/**/*.pp", "pkg/**/*.pp"]
end

def run(command)
  puts "Running #{command}"
  begin
    system(command)
  rescue => e
    raise "#{command} failed: #{e}"
  end
end

def locate_g10k
  ENV['PATH'].split(':').each do |p|
    g10k = File.join(p, 'g10k')
    if File.exists?(g10k)
      return g10k
    end
  end
  nil
end

def no_checkout
  ENV['NO_G10K'] or ENV['NO_LIBRARIAN'] or ENV['NO_CHECKOUT']
end

desc 'Generate Puppetfile'
task :generate_puppetfile do
  puppetfile = 'spec/fixtures/Puppetfile.v6'
  if Versionomy.parse(Puppet.version) < Versionomy.parse('6.0.0')
    puppetfile = 'spec/fixtures/Puppetfile.legacy'
  end
  FileUtils::cp puppetfile, 'spec/fixtures/Puppetfile'
end

desc 'Install modules with g10k'
task :g10k_spec_prep do
  raise "g10k_spec_prep called but set NO_CHECKOUT, NO_LIBRARIAN or NO_G10K set" if no_checkout

  if g10k = locate_g10k
    if RUBY_PLATFORM =~ /darwin/
      command = "#{g10k} -puppetfile"
    else
      command = "#{g10k} -puppetfile -info"
    end
  end

  run("cd spec/fixtures && #{command}")
end

desc "Run spec tests using g10k to checkout modules"
task :g10k_spec do
  Rake::Task[:generate_puppetfile].invoke
  Rake::Task[:g10k_spec_prep].invoke
  Rake::Task[:spec_prep].invoke
  Rake::Task[:spec_standalone].invoke
  Rake::Task[:spec_clean].invoke
end

verbose = ENV['LIBRARIAN_VERBOSE'] ? '--verbose' : ''

desc 'Install puppet modules with librarian-puppet'
task :librarian_spec_prep do
  raise "librarian_spec_prep called but set NO_CHECKOUT, NO_LIBRARIAN or NO_G10K set" if no_checkout
  run("cd spec/fixtures && bundle exec librarian-puppet install #{verbose}")
end

desc 'Update puppet modules with librarian-puppet'
task :librarian_update do
  system('rm -f spec/fixtures/Puppetfile.lock')
  run("cd spec/fixtures && bundle exec librarian-puppet update #{verbose}")
end

desc "Run spec tests using librarian-puppet to checkout modules"
task :librarian_spec do
  Rake::Task[:generate_puppetfile].invoke
  Rake::Task[:librarian_spec_prep].invoke
  Rake::Task[:spec_prep].invoke
  Rake::Task[:spec_standalone].invoke
  Rake::Task[:spec_clean].invoke
end

desc "Update puppet modules with g10k preferred or librarian-puppet"
if locate_g10k and !ENV['FORCE_LIBRARIAN']
  task :best_spec_prep => :g10k_spec_prep
else
  task :best_spec_prep => :librarian_spec_prep
end

desc "Run spec tests using fastest tool to checkout modules"
task :best_spec do
  Rake::Task[:generate_puppetfile].invoke
  Rake::Task[:best_spec_prep].invoke
  Rake::Task[:spec_prep].invoke
  Rake::Task[:spec_standalone].invoke
  Rake::Task[:spec_clean].invoke
end

desc "Clean Puppet 6-only modules"
task :clean_puppet_6 do
  modules = ['yum','mount','cron','augeas']
  modules.map { |x| FileUtils::rm_rf Dir.glob("spec/fixtures/modules/#{x}*") }
end

source 'https://rubygems.org'

group :development do
  gem 'pry'
  gem 'pry-rescue'
  gem 'pry-stack_explorer'
  gem 'debug_inspector', '<= 0.0.2'
  gem 'hashdiff'
  gem 'awesome_print'
  gem 'puppet-strings'
end

group :tests do
  gem 'puppetlabs_spec_helper'
  gem 'librarian-puppet'
  gem 'versionomy'
end

group :system_tests do
  gem 'beaker'
  gem 'beaker-rspec'
  gem 'beaker-puppet_install_helper'
  gem 'beaker-vagrant'
  gem 'beaker-pe'
end

gem 'facter'

if puppetversion = ENV['PUPPET_GEM_VERSION']
  gem 'puppet', puppetversion
else
  gem 'puppet'
end

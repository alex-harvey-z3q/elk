source 'https://rubygems.org'

group :development do
  gem 'pry'
  gem 'pry-rescue'
  gem 'pry-stack_explorer'
  gem 'hashdiff'
  gem 'awesome_print'
end

group :tests do
  gem 'puppetlabs_spec_helper'
  gem 'librarian-puppet'
end

group :system_tests do
  gem 'beaker'
  gem 'beaker-rspec'
  gem 'beaker-puppet_install_helper'
end

gem 'facter'

if puppetversion = ENV['PUPPET_GEM_VERSION']
  gem 'puppet', puppetversion
else
  gem 'puppet'
end

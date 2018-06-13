source 'https://rubygems.org'

gem 'rake', '~> 10.1.0'
gem 'rspec-puppet'
gem 'puppetlabs_spec_helper'
gem 'serverspec'
gem 'puppet-lint'
gem 'pry'
gem 'pry-rescue'
gem 'pry-stack_explorer'
gem 'simplecov'
gem 'beaker'
gem 'beaker-rspec'
gem 'librarian-puppet'

if facterversion = ENV['FACTER_GEM_VERSION']
  gem 'facter', facterversion
else
  gem 'facter'
end

if puppetversion = ENV['PUPPET_GEM_VERSION']
  gem 'puppet', puppetversion
else
  gem 'puppet'
end

# vim:ft=ruby

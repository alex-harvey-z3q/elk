source 'https://rubygems.org'

ruby '>= 3.0'

group :tests do
  gem 'metadata-json-lint', '~> 5.0'
  gem 'puppet-lint', '~> 4.0'
  gem 'puppetlabs_spec_helper', '~> 8.0'
  gem 'rspec-puppet', '~> 5.0'
end

group :system_tests do
  gem 'puppet_litmus', '~> 2.5'
  gem 'serverspec', '~> 2.0'
end

gem 'facter', '>= 4.0', '< 5.0'
gem 'puppet', ENV.fetch('PUPPET_GEM_VERSION', '~> 8.0')

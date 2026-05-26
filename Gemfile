source 'https://rubygems.org'

ruby '>= 3.0'

group :tests do
  gem 'bundler-audit', '~> 0.9', require: false
  gem 'metadata-json-lint', '~> 5.0'
  gem 'puppetlabs_spec_helper', '~> 8.0'
  gem 'puppet-lint', '~> 4.0'
  gem 'puppet-strings', '~> 4.1'
  gem 'rspec-puppet', '~> 5.0'
  gem 'rubocop', '~> 1.75', require: false
  gem 'rubocop-rspec', '~> 3.5', require: false
  gem 'thor', '>= 1.4.0'
  gem 'yard', '>= 0.9.42'
end

group :system_tests do
  gem 'bcrypt_pbkdf', '>= 1.0', '< 2.0'
  gem 'ed25519', '>= 1.2', '< 2.0'
  gem 'puppet_litmus', '~> 2.5'
  gem 'serverspec', '~> 2.0'
end

gem 'facter', '>= 4.0', '< 5.0'
gem 'puppet', ENV.fetch('PUPPET_GEM_VERSION', '~> 8.0')

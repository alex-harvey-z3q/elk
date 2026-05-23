# Without this, a warning is seen:
#
#   puppetlabs_spec_helper: defaults `mock_with` to `:mocha`.
#
# but the RSpec.configure needs to come before require
# puppetlabs_spec_helper.
#
RSpec.configure do |c|
  c.mock_with :mocha
end

require 'puppetlabs_spec_helper/module_spec_helper'

FileUtils::mkdir_p 'catalogs'

RSpec.configure do |c|
  c.color        = true
  c.hiera_config = 'spec/fixtures/hiera.yaml'

  c.formatter      = :documentation
  c.mock_framework = :rspec

  c.default_facts   = {
    :concat_basedir  => '/var/lib/puppet/concat',
    :espv            => '/dev/sdc',
    :id              => '1',
    :is_virtual      => true,
    :kernel          => 'Linux',
    :operatingsystem => 'Rocky',
    :operatingsystemmajrelease => '9',
    :operatingsystemrelease    => '9.3',
    :os => {
      'family' => 'RedHat',
      'name' => 'Rocky',
      'release' => {
        'major' => '9',
        'full' => '9.3',
      },
    },
    :networking => {
      'ip' => '10.10.2.15',
      'fqdn' => 'myhost.example.com',
      'hostname' => 'myhost',
      'domain' => 'example.com',
    },
    :osfamily        => 'RedHat',
    :path            => ['/bin', '/usr/bin'],
    :puppetversion   => '8.10.0',
    :selinux         => false,
    :hostname        => 'myhost',
    :domain          => 'example.com',
    :fqdn            => 'myhost.example.com',
  }
end

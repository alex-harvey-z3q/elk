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
    # required by our roles & profiles.
    :espv            => '/dev/sdc',
    :redispv         => '/dev/sdb',
    # firewall module.
    :puppetversion   => '5.5.1',
    :selinux         => false,
    :kernel          => 'Linux',
    :osfamily        => 'RedHat',
    :operatingsystem => 'RedHat',
    :operatingsystemrelease => '7.2.1511',
    # redis module.
    :operatingsystemmajrelease => '7',
    # filebeat, disable_transparent_hugepage etc.
    :os => {'family' => 'RedHat', 'release' => {'major' => '7', 'minor' => '1', 'full' => '7.1.1503'}},
    # filebeat module.
    :filebeat_version => '6',
  }
end

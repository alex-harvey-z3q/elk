require 'puppetlabs_spec_helper/module_spec_helper'

RSpec.configure do |c|
  c.color        = true
  c.hiera_config = 'spec/fixtures/hiera.yaml'
  c.formatter    = :documentation

  c.default_facts   = {
    :concat_basedir  => '/var/lib/puppet/concat',
    :espv            => '/dev/sdc',
    :kernel          => 'Linux',
    :id              => '1',
    :is_virtual      => true,
    :operatingsystem => 'RedHat',
    :operatingsystemmajrelease => '7',
    :operatingsystemrelease    => '7.2.1511',
    :osfamily        => 'RedHat',
    :path            => ['/bin', '/usr/bin'],
    :redispv         => '/dev/sdb',
    :selinux         => false,
  }
end

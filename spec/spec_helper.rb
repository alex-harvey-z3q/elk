require 'puppetlabs_spec_helper/module_spec_helper'

fixture_path = File.expand_path(File.join(__FILE__, '..', 'fixtures'))

RSpec.configure do |c|
  c.module_path     = File.join(fixture_path, 'modules')
  c.hiera_config    = File.join(fixture_path, 'hiera.yaml')
  c.environmentpath = File.join(Dir.pwd, 'spec')
  c.default_facts   = {
    :concat_basedir            => '/var/lib/puppet/concat',
    :kernel                    => 'Linux',
    :osfamily                  => 'RedHat',
    :operatingsystem           => 'RedHat',
    :operatingsystemrelease    => '7.2.1511',
    :operatingsystemmajrelease => '7',
    :path                      => ['/bin', '/usr/bin'],
    :redispv                   => '/dev/sdb',
    :espv                      => '/dev/sdc',
  }
end

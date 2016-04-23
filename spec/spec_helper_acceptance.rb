# Environment variables:
#
#   ENV['PUPPET_INSTALL_VERSION']
#     The version of Puppet to install (if 3.x) or the version of the
#     AIO agent (if 4.x). Defaults to latest Puppet 3.x.
#
#   ENV['PUPPET_INSTALL_TYPE']
#     If set to agent, the Puppet 4 agent is installed, and 
#     PUPPET_INSTALL_VERSION now specified the agent, rather than the
#     Puppet, version.  See
#     [here](https://github.com/puppetlabs/beaker-puppet_install_helper). 
#
#   ENV['BEAKER_destroy']
#     If set to 'no' Beaker will not tear down the Vagrant VM after the
#     tests run.  Use this if you want the VM to keep running for 
#     manual checking.
#   
#   ENV['YUM_UPDATE']
#     If set, a yum update will be run before testing.

require 'beaker-rspec/spec_helper'
require 'beaker-rspec/helpers/serverspec'
require 'beaker/puppet_install_helper'

def copy_modules_to(host, opts = {})
  Dir["#{opts[:source]}/*"].each do |dir|
    if File.symlink?(dir)
      scp_to host, dir, opts[:module_dir], {:ignore => 'spec/fixtures/modules'}
    else
      scp_to host, dir, opts[:dist_dir]
    end
  end
end
  
def copy_hiera_files_to(host, opts = {})
  scp_to host, opts[:hiera_yaml], opts[:target] + '/hiera.yaml'
  scp_to host, opts[:hieradata], opts[:target]
end

def copy_external_facts_to(host, opts = {})
  on host, 'mkdir -p ' + opts[:target]
  scp_to host, opts[:source], opts[:target]
end

run_puppet_install_helper

RSpec.configure do |c|
  # Project root
  proj_root = File.expand_path File.join(File.dirname(__FILE__), '..')

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    host = hosts[0]

    if ENV['YUM_UPDATE'] == 'yes'
      on host, 'yum -y update'
    end

    system 'bundle exec rake librarian_spec_prep'
    system 'bundle exec rake spec_prep'

    copy_modules_to(host, {
      :source     => proj_root + '/spec/fixtures/modules',
      :dist_dir   => '/etc/puppetlabs/code/modules',
      :module_dir => '/etc/puppetlabs/code/environments/production/modules'
    })

    copy_hiera_files_to(host, {
      :hieradata  => proj_root + '/spec/fixtures/hieradata',
      :hiera_yaml => proj_root + '/spec/fixtures/hiera.yaml.beaker',
      :target     => '/etc/puppetlabs/code',
    })

    copy_external_facts_to(host, {
      :source => proj_root + '/spec/fixtures/facts.d',
      :target => '/etc/facter',
    })

    # https://tickets.puppetlabs.com/browse/MODULES-3153
    on host, 'yum -y install iptables-services'
    on host, 'systemctl start iptables.service'
  end
end

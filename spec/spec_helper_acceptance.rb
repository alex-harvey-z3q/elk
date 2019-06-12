# Environment variables:
#
#   For Puppet 5.x and 6.x:
#
#   ENV['BEAKER_PUPPET_COLLECTION']
#     For Puppet 5 & this must be set to 'puppet5' or 'puppet6'
#
#   ENV['BEAKER_PUPPET_AGENT_VERSION']
#     Agent Version should == Puppet Version.
#
#   Usage example:
#
#   BEAKER_PUPPET_COLLECTION=puppet6 BEAKER_PUPPET_INSTALL_VERSION=6.4.2 \
#     bundle exec rspec spec/acceptance
#
#   For Puppet 4.x:
#
#   ENV['BEAKER_PUPPET_COLLECTION']
#     For Puppet 4 this must be set to 'pc1'
#
#   ENV['BEAKER_PUPPET_AGENT_VERSION']
#     For Puppet 4, Agent Version != Puppet Version. The conversion is
#     documented here:
#       https://puppet.com/docs/puppet/4.10/about_agent.html
#
#   Usage example (for Puppet 4.10.12):
#
#   BEAKER_PUPPET_COLLECTION=pc1 BEAKER_PUPPET_INSTALL_VERSION=1.10.12 \
#     bundle exec rspec spec/acceptance
#
#   Other variables:
#
#   ENV['BEAKER_destroy']
#     If set to 'no' Beaker will not tear down the Vagrant VM after the
#     tests run.  Use this if you want the VM to keep running for 
#     manual checking.
#   
#   ENV['YUM_UPDATE']
#     If set, a yum update will be run before testing.

require 'beaker-pe'
require 'beaker-puppet'
require 'beaker-rspec'
require 'beaker/puppet_install_helper'
require 'puppet'

def copy_modules_to(host, opts = {})
  Dir["#{opts[:source]}/*"].each do |dir|
    if File.symlink?(dir)
      scp_to host, dir, opts[:module_dir],
        {:ignore => 'spec/fixtures/modules'}
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
  on host, "mkdir -p #{opts[:target]}"
  scp_to host, opts[:source], opts[:target]
end

run_puppet_install_helper

RSpec.configure do |c|
  proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  c.formatter = :documentation

  # Configure all nodes in nodeset
  # See spec/acceptance/nodesets/default.yml
  #
  c.before :suite do
    host = hosts[0]

    if ENV['YUM_UPDATE'] == 'yes'
      on host, 'yum -y update'
    end

    system 'bundle exec rake best_spec_prep'
    system 'bundle exec rake spec_prep'

    copy_modules_to(host, {
      :source     => "#{proj_root}/spec/fixtures/modules",
      :dist_dir   => '/etc/puppetlabs/code/modules',
      :module_dir => '/etc/puppetlabs/code/environments/production/modules'
    })

    copy_hiera_files_to(host, {
      :hieradata  => "#{proj_root}/spec/fixtures/hieradata",
      :hiera_yaml => "#{proj_root}/spec/fixtures/hiera.yaml.beaker",
      :target     => '/etc/puppetlabs/code',
    })

    copy_external_facts_to(host, {
      :source => "#{proj_root}/spec/fixtures/facts.d",
      :target => '/etc/facter',
    })

    # https://tickets.puppetlabs.com/browse/MODULES-3153
    # https://tickets.puppetlabs.com/browse/MODULES-3184
    on host, 'yum -y install iptables-services'
    on host, 'systemctl start iptables.service'
    on host, 'systemctl start ip6tables.service'
  end
end

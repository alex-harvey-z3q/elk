require 'spec_helper_acceptance'

pp = <<-EOS
stage { 'pre': before => Stage['main'] }

Firewall {
  require => Class['profile::base::firewall::pre'],
  before  => Class['profile::base::firewall::post'],
}

include role::es_data_node
EOS

describe 'role::es_data_node' do
  context 'puppet apply' do
    it 'is expected to be idempotent and apply without errors' do

      apply_manifest pp, :catch_failures => true

      # test for idempotence
      expect(apply_manifest(pp, :catch_failures => true).exit_code).to be_zero
    end
  end

  context 'packages' do

    [
     ['java-1.8.0-openjdk',          '1.8.0'],
     ['java-1.8.0-openjdk-headless', '1.8.0'],
     ['elasticsearch',               '2.3.1'],
     ['elastic-curator',             '3.2.3'],
     ['python-elasticsearch',        '1.0.0'],

    ].each do |package, version|

      describe package(package) do
        it { is_expected.to be_installed.with_version(version) }
      end

    end

  end

  context 'config files' do
    describe file('/usr/lib/tmpfiles.d/elasticsearch.conf') do
      its(:content) { is_expected.to match /elasticsearch/ }
    end

    describe file('/etc/elasticsearch/es01/logging.yml') do
      its(:content) { is_expected.to match /managed by Puppet/ }
    end

    describe file('/etc/elasticsearch/es01/elasticsearch.yml') do
      its(:content) { is_expected.to match /MANAGED BY PUPPET/ }
    end

    describe file('/lib/systemd/system/elasticsearch-es01.service') do
      it { is_expected.to be_file }
    end
  end

  context 'log files' do
    describe file('/var/log/elasticsearch/es01/es01.log') do
      its(:content) { is_expected.to match /starting .../ }
      its(:content) { is_expected.to match /publish_address.*127.0.0.1:9300/ }
      its(:content) { is_expected.to match /es01/ }
      its(:content) { is_expected.to match /new_master.*reason:.*elected_as_master/ }
      its(:content) { is_expected.to match /publish_address.*127.0.0.1:9200/ }
      its(:content) { is_expected.to match /started/ }
    end

    describe file('/var/log/elasticsearch/es01/es01_index_search_slowlog.log') do
      its(:size) { is_expected.to be_zero }
    end

    describe file('/var/log/elasticsearch/es01/es01_index_indexing_slowlog.log') do
      its(:size) { is_expected.to be_zero }
    end

    describe file('/var/log/elasticsearch/es01/gc.log.0.current') do
      its(:content) { is_expected.to match /OpenJDK 64-Bit Server VM/ }
    end
  end

  context 'mount points' do
    describe file('/srv/es') do
      it { is_expected.to be_directory }
      it { is_expected.to be_owned_by 'elasticsearch' }
      it { is_expected.to be_grouped_into 'root' }
      it { is_expected.to be_mounted.with(:type => 'ext4') }
    end
  end

  context 'users' do

    [
     ['elasticsearch', 30000],

    ].each do |user, uid|

      describe user(user) do
        it { is_expected.to exist }
        it { is_expected.to have_uid uid }
      end

    end

  end

  context 'kernel parameters' do

    describe linux_kernel_parameter('vm.max_map_count') do
      its(:value) { is_expected.to eq 262144 }
    end

    describe linux_kernel_parameter('vm.swappiness') do
      its(:value) { is_expected.to eq 0 }
    end

  end

  context 'commands' do
    describe command('curl localhost:9200') do
      its(:stdout) { is_expected.to match /cluster_name.*es01/ }
    end

    describe command('curl localhost:9200/_cluster/health?pretty') do
      its(:stdout) { is_expected.to match /green/ }
    end
  end
end

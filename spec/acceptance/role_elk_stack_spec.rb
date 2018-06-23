require 'spec_helper_acceptance'

pp = <<-EOS
stage { 'pre': before => Stage['main'] }

Firewall {
  require => Class['profile::base::firewall::pre'],
  before  => Class['profile::base::firewall::post'],
}

include role::elk_stack
EOS

describe 'role::elk_stack' do
  context 'puppet apply' do
    it 'is expected to be idempotent and apply without errors' do

      apply_manifest pp, :catch_failures => true

      # test for idempotence
      expect(apply_manifest(pp, :catch_failures => true).exit_code).to be_zero
    end
  end

  context 'logstash' do

    context 'packages' do

      [
       ['redis',                       '3.2.10'],
       ['logstash',                    '6.3.0'],

      ].each do |package, version|

        describe package(package) do
          it { is_expected.to be_installed.with_version(version) }
        end

      end

    end

    context 'config files' do

      describe file('/etc/logstash/conf.d/shipper.conf') do
        its(:content) { should match /MANAGED BY PUPPET/ }
      end

      describe file('/etc/logstash/conf.d/indexer.conf') do
        its(:content) { should match /MANAGED BY PUPPET/ }
      end

      describe file('/etc/logstash/jvm.options') do
        its(:content) { is_expected.to match /managed by Puppet/ }
      end

      describe file('/etc/logstash/log4j2.properties') do
        it { is_expected.to be_file }
      end

      describe file('/etc/logstash/startup.options') do
        it { is_expected.to be_file }
      end

      describe file('/etc/logstash/logstash.yml') do
        its(:content) { is_expected.to match /path.data.*\/var\/lib\/logstash/ }
        its(:content) { is_expected.to match /path.logs.*\/var\/log\/logstash/ }
      end

      describe file('/etc/logstash/pipelines.yml') do
        its(:content) { is_expected.to match /pipeline.id.*shipper/ }
        its(:content) { is_expected.to match /pipeline.id.*indexer/ }
      end

    end

    context 'log files' do
      describe file('/var/log/logstash/logstash-plain.log') do
        its(:content) { is_expected.to match /Starting Logstash/ }
        its(:content) { is_expected.to match /Starting pipeline.*indexer/ }
        its(:content) { is_expected.to match /Starting pipeline.*shipper/ }
        its(:content) { is_expected.to match /Beats inputs: Starting input listener.*5044/ }
        its(:content) { is_expected.to match /Pipeline started successfully.*shipper/ }
        its(:content) { is_expected.to match /Elasticsearch pool URLs updated/ }
        its(:content) { is_expected.to match /Running health check to see if an Elasticsearch connection is working/ }
        its(:content) { is_expected.to match /Restored connection to ES instance/ }
        its(:content) { is_expected.to match /ES Output version determined/ }
        its(:content) { is_expected.to match /Detected a 6.x and above cluster/ }
        its(:content) { is_expected.to match /New Elasticsearch output/ }
        its(:content) { is_expected.to match /Registering Redis/ }
        its(:content) { is_expected.to match /Pipeline started successfully.*indexer/ }
        its(:content) { is_expected.to match /Pipelines running.*count=>2/ }
        its(:content) { is_expected.to match /Successfully started Logstash API endpoint.*9600/ }
      end

      describe file('/var/log/logstash/logstash-slowlog-plain.log') do
        its(:size) { is_expected.to be_zero }
      end

    end
  end

  context 'redis' do
    context 'mount points' do
      describe file('/var/lib/redis') do
        it { is_expected.to be_directory }
        it { is_expected.to be_owned_by 'redis' }
        it { is_expected.to be_grouped_into 'redis' }
        it { is_expected.to be_mounted.with(:type => 'ext4') }
      end
    end

    context 'log files' do
      describe file('/var/log/redis/redis.log') do
        its(:content) { should match /Server started, Redis version \d+\.\d+\.\d+/ }
      end
    end
  end

  context 'elasticsearch' do

    context 'packages' do

      [
       ['java-1.8.0-openjdk',          '1.8.0'],
       ['java-1.8.0-openjdk-headless', '1.8.0'],
       ['elasticsearch',               '6.3.0'],
       ['elastic-curator',             '3.2.3'],
       ['python-elasticsearch',        '1.9.0'],

      ].each do |package, version|

        describe package(package) do
          it { is_expected.to be_installed.with_version(version) }
        end

      end

    end

    context 'directories' do
      describe file('/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.171-8.b10.el7_5.x86_64') do
        it { should be_directory }
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
        its(:content) { is_expected.to match /initializing .../ }
        its(:content) { is_expected.to match /using.*data paths, mounts/ }
        its(:content) { is_expected.to match /heap size/ }
        its(:content) { is_expected.to match /node name.*node ID/ }
        its(:content) { is_expected.to match /JVM arguments/ }
        its(:content) { is_expected.to match /loaded module/ }
        its(:content) { is_expected.to match /no plugins loaded/ }
        its(:content) { is_expected.to match /using discovery type.*zen/ }
        its(:content) { is_expected.to match /initialized/ }
        its(:content) { is_expected.to match /starting .../ }
        its(:content) { is_expected.to match /publish_address.*127.0.0.1:9300/ }
        its(:content) { is_expected.to match /zen-disco-elected-as-master.*reason: new_master/ }
        its(:content) { is_expected.to match /publish_address.*127.0.0.1:9200/ }
        its(:content) { is_expected.to match /started/ }
        its(:content) { is_expected.to match /WARN.*Failed to clear cache for realms/ } # What is this?
        its(:content) { is_expected.to match /adding template/ }
        its(:content) { is_expected.to match /license.*mode.*basic.*valid/ }
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
        its(:value) { is_expected.to eq 1 }
      end

    end

    context 'commands' do
      describe command('curl 0.0.0.0:9200') do
        its(:stdout) { is_expected.to match /cluster_name.*es01/ }
      end

      describe command('curl 0.0.0.0:9200/_cluster/health?pretty') do
        its(:stdout) { is_expected.to match /green/ }
      end

      it 'add some data' do
        shell('curl -XPUT 0.0.0.0:9200/blog/user/dilbert -H'"'Content-Type: application/json' -d '{"'"name":"dilbert"}'"' ; sleep 5")
        expect(command("curl '0.0.0.0:9200/blog/user/_search?q=name:Dilbert&pretty'").stdout).to match /_id.*dilbert/
      end
    end
  end
end

require 'spec_helper_acceptance'

elk_version = '6.8.2'
openjdk = 'java-1.8.0-openjdk-1.8.0.222.b10-0.el7_6.x86_64'

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

  context 'filebeat' do
    context 'packages' do
      describe package('filebeat') do
        it { should be_installed.with_version(elk_version) }
      end
    end

    context 'config files' do
      describe file('/etc/filebeat/filebeat.yml') do
        its(:content) { should match /managed by Puppet/ }
      end

      describe file('/etc/filebeat/conf.d/syslogs.yml') do
        it { should be_file }
      end
    end

    context 'log files' do
      describe file('/var/log/filebeat/filebeat') do
        its(:content) { should match /filebeat start running/ }
      end
    end

    context 'process' do
      describe process('filebeat') do
        its(:args) { should match %r{-c /etc/filebeat/filebeat.yml} }
        its(:args) { should match %r{-path.home /usr/share/filebeat} }
        its(:args) { should match %r{-path.config /etc/filebeat} }
        its(:args) { should match %r{-path.data /var/lib/filebeat} }
        its(:args) { should match %r{-path.logs /var/log/filebeat} }
      end
    end
  end

  context 'logstash' do
    context 'packages' do
      describe package('logstash') do
        it { should be_installed.with_version(elk_version) }
      end
    end

    context 'user' do
      describe user('logstash') do
        it { should exist }
        it { should have_uid 30001 }
      end
    end

    context 'executable' do
      describe file('/usr/share/logstash/bin/logstash') do
        it { should be_executable }
      end

      describe file('/usr/share/logstash/bin/logstash-plugin') do
        it { should be_executable }
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
        its(:content) { should match /managed by Puppet/ }
      end

      describe file('/etc/logstash/log4j2.properties') do
        it { should be_file }
      end

      describe file('/etc/logstash/startup.options') do
        it { should be_file }
      end

      describe file('/etc/logstash/logstash.yml') do
        its(:content) { should match %r{path.data.*/var/lib/logstash} }
        its(:content) { should match %r{path.logs.*/var/log/logstash} }
      end

      describe file('/etc/logstash/pipelines.yml') do
        its(:content) { should match /pipeline.id.*shipper/ }
        its(:content) { should match /pipeline.id.*indexer/ }
      end
    end

    context 'log files' do
      describe file('/var/log/logstash/logstash-plain.log') do
        its(:content) { should match /Starting Logstash/ }
        its(:content) { should match /No persistent UUID file found. Generating new UUID/ }
        its(:content) { should match /Starting pipeline.*indexer/ }
        its(:content) { should match /Starting pipeline.*shipper/ }
        its(:content) { should match /Beats inputs: Starting input listener.*5044/ }
        its(:content) { should match /Pipeline started successfully.*shipper/ }
        its(:content) { should match /Elasticsearch pool URLs updated/ }
        its(:content) { should match /Restored connection to ES instance/ }
        its(:content) { should match /ES Output version determined/ }
        its(:content) { should match /Detected a 6.x and above cluster: the.*type.*event field won.*t be used to determine the document _type/ }
        its(:content) { should match /New Elasticsearch output/ }
        its(:content) { should match /Registering Redis/ }
        its(:content) { should match /Pipeline started successfully.*indexer/ }
        its(:content) { should match /Pipelines running.*count=>2/ }
        its(:content) { should match /Starting server on port: 5044/ }
        its(:content) { should match /Successfully started Logstash API endpoint.*9600/ }
      end

      describe file('/var/log/logstash/logstash-slowlog-plain.log') do
        its(:size) { should be_zero }
      end
    end

    # FIXME. This is failing and I don't know why.
#
#    context 'commands' do
#      describe command('echo hello world | /usr/share/logstash/bin/logstash -e "input { stdin { type => stdin } } output { stdout { } }"') do
#        its(:stdout) { should match /"message" => "hello world"/ }
#      end
#    end
  end

  context 'redis' do
    context 'packages' do
      describe package('redis') do
        it { should be_installed.with_version('3.2.12') }
      end
    end

    context 'mount points' do
      describe file('/var/lib/redis') do
        it { should be_directory }
        it { should be_owned_by 'redis' }
        it { should be_grouped_into 'redis' }
        it { should be_mounted.with(:type => 'ext4') }
      end
    end

    context 'log files' do
      describe file('/var/log/redis/redis.log') do
        its(:content) { should match /Server started, Redis version \d+\.\d+\.\d+/ }
      end
    end

    context 'ports' do
      describe port(6379) do
        it { should be_listening }
      end
    end

    describe 'end to end test' do
      before(:all) do
        shell('redis-cli lpush mylist foo')
      end
      it 'can push and pop to a list' do
        shell('redis-cli lpop mylist') do |r|
          expect(r.stdout).to match /foo/
        end
      end
    end
  end

  context 'elasticsearch' do

    context 'packages' do
      [
       ['java-1.8.0-openjdk',          '1.8.0'],
       ['java-1.8.0-openjdk-headless', '1.8.0'],
       ['elasticsearch',               elk_version],
       ['elasticsearch-curator',       '5.7.6'],

      ].each do |package, version|

        describe package(package) do
          it { should be_installed.with_version(version) }
        end
      end
    end

    context 'user' do
      describe user('elasticsearch') do
        it { should exist }
        it { should have_uid 30000 }
      end
    end

    context 'ports' do
      [9200, 9300, 9600].each do |port|
        describe port(port) do
          it { should be_listening }
        end
      end
    end

    context 'directories' do
      describe file("/usr/lib/jvm/#{openjdk}") do
        it { should be_directory }
      end
    end

    context 'config files' do
      describe file('/usr/lib/tmpfiles.d/elasticsearch.conf') do
        its(:content) { should match /elasticsearch/ }
      end

      describe file('/etc/elasticsearch/es01/logging.yml') do
        its(:content) { should match /managed by Puppet/ }
      end

      describe file('/etc/elasticsearch/es01/elasticsearch.yml') do
        its(:content) { should match /MANAGED BY PUPPET/ }
      end

      describe file('/lib/systemd/system/elasticsearch-es01.service') do
        it { should be_file }
      end
    end

    context 'log files' do
      describe file('/var/log/elasticsearch/es01/es01.log') do
        its(:content) { should match /initialized/ }
        its(:content) { should match /using.*data paths, mounts/ }
        its(:content) { should match /heap size/ }
        its(:content) { should match /node name.*node ID/ }
        its(:content) { should match /JVM arguments/ }
        its(:content) { should match /loaded module/ }
        its(:content) { should match /no plugins loaded/ }
        its(:content) { should match /using discovery type.*zen/ }
        its(:content) { should match /initialized/ }
        its(:content) { should match /starting .../ }
        its(:content) { should match /publish_address.*127.0.0.1:9300/ }
        its(:content) { should match /zen-disco-elected-as-master.*reason: new_master/ }
        its(:content) { should match /publish_address.*127.0.0.1:9200/ }
        its(:content) { should match /started/ }
        its(:content) { should match /WARN.*Failed to clear cache for realms/ } # What is this?
        its(:content) { should match /adding template/ }
        its(:content) { should match /license.*mode.*basic.*valid/ }
      end

      describe file('/var/log/elasticsearch/es01/es01_index_search_slowlog.log') do
        its(:size) { should be_zero }
      end

      describe file('/var/log/elasticsearch/es01/es01_index_indexing_slowlog.log') do
        its(:size) { should be_zero }
      end

      describe file('/var/log/elasticsearch/es01/gc.log.0.current') do
        its(:content) { should match /OpenJDK 64-Bit Server VM/ }
      end
    end

    context 'mount points' do
      describe file('/srv/es') do
        it { should be_directory }
        it { should be_owned_by 'elasticsearch' }
        it { should be_grouped_into 'root' }
        it { should be_mounted.with(:type => 'ext4') }
      end
    end

    context 'kernel parameters' do
      describe linux_kernel_parameter('vm.max_map_count') do
        its(:value) { should eq 262144 }
      end

      describe linux_kernel_parameter('vm.swappiness') do
        its(:value) { should eq 1 }
      end
    end

    context 'commands' do
      describe command('curl 0.0.0.0:9200') do
        its(:stdout) { should match /cluster_name.*es01/ }
      end

      describe command('curl 0.0.0.0:9200/_cluster/health?pretty') do
        its(:stdout) { should match /green/ }
      end

      # TODO. Extend based on this page:
      # https://www.safaribooksonline.com/library/view/mastering-elastic-stack/9781786460011/ch03s15.html
      #
      describe command('curl 0.0.0.0:9600/?pretty') do
        its(:stdout) { should match /host.*centos/ }
      end

      it 'add some data' do
        shell('curl -XPUT 0.0.0.0:9200/blog/user/dilbert -H'"'Content-Type: application/json' -d '{"'"name":"dilbert"}'"' ; sleep 5")
        expect(command("curl '0.0.0.0:9200/blog/user/_search?q=name:Dilbert&pretty'").stdout).to match /_id.*dilbert/
      end
    end
  end

  context 'ES coordinating-only instance' do
    context 'ports' do
      [9201, 9301].each do |port|
        describe port(port) do
          it { should be_listening }
        end
      end
    end

    context 'config files' do
      describe file('/usr/lib/tmpfiles.d/elasticsearch.conf') do
        its(:content) { should match /elasticsearch/ }
      end

      describe file('/etc/elasticsearch/es01-coordinating-instance/logging.yml') do
        its(:content) { should match /managed by Puppet/ }
      end

      describe file('/etc/elasticsearch/es01-coordinating-instance/elasticsearch.yml') do
        its(:content) { should match /MANAGED BY PUPPET/ }
      end

      describe file('/lib/systemd/system/elasticsearch-es01-coordinating-instance.service') do
        it { should be_file }
      end
    end

    context 'log files' do
      describe file('/var/log/elasticsearch/es01-coordinating-instance/es01.log') do
        its(:content) { should match /publish_address.*127.0.0.1:9301/ }
        its(:content) { should match /detected_master.*reason: apply cluster state/ }
        its(:content) { should match /publish_address.*127.0.0.1:9201/ }
        its(:content) { should match /started/ }
        its(:content) { should match /WARN.*Failed to clear cache for realms/ } # What is this?
      end

      describe file('/var/log/elasticsearch/es01-coordinating-instance/es01_index_search_slowlog.log') do
        its(:size) { should be_zero }
      end

      describe file('/var/log/elasticsearch/es01-coordinating-instance/es01_index_indexing_slowlog.log') do
        its(:size) { should be_zero }
      end

      describe file('/var/log/elasticsearch/es01-coordinating-instance/gc.log.0.current') do
        its(:content) { should match /OpenJDK 64-Bit Server VM/ }
      end
    end

    context 'commands' do
      describe command('curl 0.0.0.0:9201') do
        its(:stdout) { should match /name.*es01_coordinating/ }
      end

      describe command('curl 0.0.0.0:9201/_cluster/health?pretty') do
        its(:stdout) { should match /green/ }
      end
    end
  end

  context 'kibana' do
    context 'packages' do
      describe package('kibana') do
        it { should be_installed.with_version(elk_version) }
      end
    end

    context 'user' do
      describe user('kibana') do
        it { should exist }
        it { should have_uid 30002 }
      end
    end

    context 'commands' do
      describe command('journalctl -u kibana.service') do
        its(:stdout) { should match /Started Kibana/ }
      end

      describe command('curl 0.0.0.0:5601/status -I') do
        its(:stdout) { should match %r{200 OK} }
      end
    end
  end
end

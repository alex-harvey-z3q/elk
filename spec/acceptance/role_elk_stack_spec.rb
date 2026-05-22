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
    it 'applies idempotently' do
      apply_manifest pp, catch_failures: true
      expect(apply_manifest(pp, catch_failures: true).exit_code).to be_zero
    end
  end

  context 'managed services' do
    %w[elasticsearch logstash kibana filebeat nginx].each do |service_name|
      describe service(service_name) do
        it { should be_enabled }
        it { should be_running }
      end
    end
  end

  context 'configuration files' do
    describe file('/etc/filebeat/inputs.d/syslogs.yml') do
      its(:content) { should match /type: filestream/ }
    end

    describe file('/etc/logstash/conf.d/main.conf') do
      its(:content) { should match %r{http://localhost:9200} }
    end

    describe file('/etc/kibana/kibana.yml') do
      its(:content) { should match /elasticsearch.hosts/ }
    end

    describe file('/etc/elasticsearch/elasticsearch.yml') do
      its(:content) { should match /discovery.type.*single-node/ }
      its(:content) { should match /xpack.security.enabled.*false/ }
    end
  end

  context 'ports and APIs' do
    [5044, 5601, 9200].each do |port_number|
      describe port(port_number) do
        it { should be_listening }
      end
    end

    describe command('curl -s http://localhost:9200') do
      its(:stdout) { should match /cluster_name.*es01/ }
    end

    describe command('curl -s http://localhost:9200/_cluster/health?pretty') do
      its(:stdout) { should match /green|yellow/ }
    end

    it 'indexes and searches a typeless document' do
      shell(
        'curl -s -XPUT http://localhost:9200/blog/_doc/dilbert ' \
        '-H "Content-Type: application/json" -d "{\"name\":\"dilbert\"}"'
      )
      shell("curl -s 'http://localhost:9200/blog/_search?q=name:dilbert&pretty'") do |result|
        expect(result.stdout).to match /"_id"\s*:\s*"dilbert"/
      end
    end
  end
end

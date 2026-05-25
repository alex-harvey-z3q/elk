require 'spec_helper_acceptance'

pp = <<-EOS
stage { 'pre': before => Stage['main'] }

include role::elk_multi_node
EOS

role_expectations = {
  'elasticsearch' => {
    service: 'enables/runs Elasticsearch and listens on tcp/9200',
    config: 'sets network.host to 0.0.0.0 in /etc/elasticsearch/elasticsearch.yml',
  },
  'logstash' => {
    service: 'enables/runs Logstash and listens on tcp/5044',
    config: 'sends Logstash output to http://10.43.1.10:9200',
  },
  'kibana' => {
    service: 'enables/runs Kibana and listens on tcp/5601',
    config: 'points Kibana at http://10.43.1.10:9200',
  },
  'edge' => {
    service: 'enables/runs nginx and listens on tcp/80',
    config: 'proxies nginx traffic to Kibana at 10.43.1.12:5601',
  },
}

expected_role = ENV.fetch('ELK_LAB_ROLE', nil)
role_label = expected_role || 'target node'
service_expectation = role_expectations.dig(expected_role, :service) || 'runs the service and listener for the target role'
config_expectation = role_expectations.dig(expected_role, :config) || 'writes the endpoint configuration for the target role'

describe "role::elk_multi_node on #{role_label}" do
  let(:elk_lab_role) { command('facter -p elk_lab_role').stdout.strip }

  context 'Puppet catalog' do
    it "reports elk_lab_role as #{role_label}" do
      expect(elk_lab_role).to eq(expected_role) if expected_role
      expect(elk_lab_role).not_to be_empty
    end

    it "applies idempotently for the #{role_label} role" do
      apply_manifest(pp, catch_failures: true, hiera_config: '/etc/puppetlabs/code/hiera.yaml')
      idempotent_apply(pp, hiera_config: '/etc/puppetlabs/code/hiera.yaml')
    end
  end

  context 'common telemetry service' do
    it "enables and runs Filebeat on the #{role_label} node" do
      expect(service('filebeat')).to be_enabled
      expect(service('filebeat')).to be_running
    end
  end

  context 'role-specific service and listener' do
    it service_expectation do
      case elk_lab_role
      when 'elasticsearch'
        expect(service('elasticsearch')).to be_enabled
        expect(service('elasticsearch')).to be_running
        expect(port(9200)).to be_listening
      when 'logstash'
        expect(service('logstash')).to be_enabled
        expect(service('logstash')).to be_running
        expect(port(5044)).to be_listening
      when 'kibana'
        expect(service('kibana')).to be_enabled
        expect(service('kibana')).to be_running
        expect(port(5601)).to be_listening
      when 'edge'
        expect(service('nginx')).to be_enabled
        expect(service('nginx')).to be_running
        expect(port(80)).to be_listening
      else
        raise "Unexpected elk_lab_role #{elk_lab_role.inspect}"
      end
    end
  end

  context 'role-specific cross-node configuration' do
    it config_expectation do
      case elk_lab_role
      when 'elasticsearch'
        expect(file('/etc/elasticsearch/elasticsearch.yml').content).to match /network.host.*0.0.0.0/
      when 'logstash'
        expect(file('/etc/logstash/conf.d/main.conf').content).to match %r{http://10\.43\.1\.10:9200}
      when 'kibana'
        expect(file('/etc/kibana/kibana.yml').content).to match %r{http://10\.43\.1\.10:9200}
      when 'edge'
        expect(command('nginx -T 2>/dev/null').stdout).to match %r{10\.43\.1\.12:5601}
      end
    end
  end
end

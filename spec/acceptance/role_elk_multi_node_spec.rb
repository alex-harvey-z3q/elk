require 'spec_helper_acceptance'

pp = <<-EOS
stage { 'pre': before => Stage['main'] }

include role::elk_multi_node
EOS

describe 'role::elk_multi_node' do
  let(:elk_lab_role) { command('facter -p elk_lab_role').stdout.strip }

  context 'puppet apply' do
    it 'applies idempotently' do
      apply_manifest(pp, catch_failures: true, hiera_config: '/etc/puppetlabs/code/hiera.yaml')
      idempotent_apply(pp, hiera_config: '/etc/puppetlabs/code/hiera.yaml')
    end
  end

  context 'common services' do
    describe service('filebeat') do
      it { should be_enabled }
      it { should be_running }
    end
  end

  context 'role-specific services' do
    it 'runs the expected service set' do
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

  context 'role-specific configuration' do
    it 'writes the expected cross-node endpoints' do
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

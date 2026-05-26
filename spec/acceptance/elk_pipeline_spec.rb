require 'json'
require 'open3'
require 'securerandom'
require 'shellwords'
require 'uri'

RSpec.describe 'ELK event pipeline' do
  let(:log_source_target) { ENV.fetch('LOG_SOURCE_TARGET') }
  let(:elasticsearch_target) { ENV.fetch('ELASTICSEARCH_TARGET') }
  let(:elasticsearch_url) { ENV.fetch('ELASTICSEARCH_URL') }
  let(:inventory_file) { 'spec/fixtures/litmus_inventory.yaml' }

  def bolt_command(target, command)
    stdout, stderr, status = Open3.capture3(
      'bundle',
      'exec',
      'bolt',
      'command',
      'run',
      command,
      '--targets',
      target,
      '--inventoryfile',
      inventory_file,
      '--format',
      'json',
      '--no-color'
    )
    raise "Bolt command failed on #{target}: #{stderr}\n#{stdout}" unless status.success?

    result = JSON.parse(stdout).fetch('items').first
    raise "Bolt command failed on #{target}: #{result.inspect}" unless result.fetch('status') == 'success'

    result.fetch('value')
  end

  def wait_for_indexed_event(event_id)
    query = URI.encode_www_form(q: event_id)
    search_url = "#{elasticsearch_url}/logstash-*/_search?#{query}"

    24.times do
      result = bolt_command(elasticsearch_target, "curl -s #{Shellwords.escape(search_url)}")
      body = result.fetch('stdout')
      parsed = JSON.parse(body)
      return parsed if parsed.dig('hits', 'total', 'value').to_i.positive? && body.include?(event_id)

      sleep 5
    end

    nil
  end

  it 'ships a log event through Filebeat, Logstash and Elasticsearch' do
    event_id = "elk-pipeline-#{SecureRandom.uuid}"
    log_line = "elk_pipeline_acceptance_id=#{event_id} message='pipeline smoke test'"
    append_command = "printf '%s\\n' #{Shellwords.escape(log_line)} >> /var/log/testlog"

    bolt_command(log_source_target, append_command)
    indexed_event = wait_for_indexed_event(event_id)

    expect(indexed_event).not_to be_nil
  end
end

require 'spec_helper'
require 'puppet/file_serving'

describe 'role::elk_stack' do

  # This setup is to work-around the Elasticsearch Template custom type as seen
  # here: https://github.com/elastic/puppet-elasticsearch/blob/
  #   eef10e8ac99d9295c4297234b684471bdad42014/lib/puppet/type/
  #   elasticsearch_template.rb#L90-L109
  #
  # where this custom type retrieves content from Puppet's FileServing
  # indirection.
  #
  before(:each) do
    allow(Puppet::FileServing::Metadata.indirection).to receive(:find).
      and_call_original

    allow(Puppet::FileServing::Metadata.indirection).to receive(:find).
      with('puppet:///modules/profile/logstash/logstash.json').and_return(true)

    class Fake
      def content
        File.read('./site/modules/profile/files/logstash/logstash.json')
      end
    end

    allow(Puppet::FileServing::Content.indirection).to receive(:find).
      with(
        'puppet:///modules/profile/logstash/logstash.json',
        hash_including(environment: instance_of(Puppet::Node::Environment))
      ).and_return(Fake.new)
  end

  it 'should write a compiled catalog' do
    is_expected.to compile.with_all_deps
    File.write(
      'catalogs/role__elk_stack.json',
      PSON.pretty_generate(catalogue)
    )
  end
end

require 'spec_helper'

describe 'role::elk_multi_node' do
  %w[elasticsearch logstash kibana edge].each do |role|
    context "when elk_lab_role is #{role}" do
      let(:facts) do
        RSpec.configuration.default_facts.merge('elk_lab_role' => role)
      end

      it { is_expected.to compile.with_all_deps }
    end
  end
end

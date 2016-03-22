require 'spec_helper'

describe 'role::es_data_node' do
  it { is_expected.to compile.with_all_deps }
end

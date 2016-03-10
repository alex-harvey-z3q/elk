require 'spec_helper'

describe 'role::elk_stack' do
  it { is_expected.to compile.with_all_deps }
end

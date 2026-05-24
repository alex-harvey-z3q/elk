require 'spec_helper'
require 'json'

describe 'role::elk_stack' do
  it 'should write a compiled catalog' do
    is_expected.to compile.with_all_deps
    File.write(
      'catalogs/role__elk_stack.json',
      JSON.pretty_generate(catalogue.to_data_hash)
    )
  end
end

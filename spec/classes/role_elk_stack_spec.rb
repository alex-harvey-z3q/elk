require 'spec_helper'
require 'json'

describe 'role::elk_stack' do
  it 'writes a compiled catalog' do
    expect(subject).to compile.with_all_deps
    File.write(
      'catalogs/role__elk_stack.json',
      JSON.pretty_generate(catalogue.to_data_hash)
    )
  end
end

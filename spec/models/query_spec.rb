require_relative '../spec_helper'

describe Models::Query do
  it 'should remove single line comments' do
    expect(Models::Query.query_for_display("-- test comment\nSELECT 1")).to eq('SELECT 1')
  end
  it 'should remove single line comments without newlines' do
    expect(Models::Query.query_for_display("-- test comment")).to eq('')
  end

  it 'should remove multi line comments' do
    expect(Models::Query.query_for_display("/* test comment */SELECT 1")).to eq('SELECT 1')
    expect(Models::Query.query_for_display("/* test comment\nsecond line */SELECT 1")).to eq('SELECT 1')
  end

  it 'should remove comments single and multi line comments' do
    expect(Models::Query.query_for_display(
      "/* test comment\n--second line*/\nSELECT 1\n/* test comment2 */")).to eq('SELECT 1')
  end

  it 'should remove single and multi line comment combinations' do
    expect(Models::Query.query_for_display(
      "/* test comment\n/*second line*/*/\nSELECT 1")).to eq('SELECT 1')
  end
end

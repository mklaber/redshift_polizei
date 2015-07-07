require_relative '../../spec_helper'

describe Jobs::TableReports do
  def create_report(options={})
    connection_id = 'redshift_test'
    RSPool.with do |c|
      begin
        schema_name = options[:schema_name] || @config[:export_schema]
        table_name = options[:table_name] || "polizei_test_#{rand(1024)}"
        create_sql = options[:create_sql] || "CREATE TABLE #{schema_name}.#{table_name}(id INT, txt VARCHAR)"
        c.exec(create_sql) unless options[:donotcreate]
        Jobs::TableReports.enqueue(1, 1, { schema_name: schema_name, table_name: table_name }.merge(options))
      ensure
        c.exec("DROP TABLE IF EXISTS #{schema_name}.#{table_name}") unless options[:donotcreate]
      end
    end
  end

  def create_and_return_report(options={})
    schema_name = options[:schema_name] || @config[:export_schema]
    table_name = options[:table_name] || "polizei_test_#{rand(1024)}"
    create_report({ schema_name: schema_name, table_name: table_name }.merge(options))
    Models::TableReport.where(schema_name: schema_name, table_name: table_name).first
  end

  it 'should create report on a table' do
    schema_name = @config[:export_schema]
    table_name = "polizei_test_#{rand(1024)}"
    report = create_and_return_report(schema_name: schema_name, table_name: table_name)
    expect(report.schema_name).to eq(schema_name)
    expect(report.table_name).to eq(table_name)
    expect(report.table_id.nil?).to eq(false)
    expect(report.size_in_mb).to eq(0)
    expect(report.pct_skew_across_slices.nil?).to eq(false)
    expect(report.pct_slices_populated.nil?).to eq(false)
    expect(report.dist_key.nil?).to eq(true)
    expect(report.sort_keys.empty?).to eq(true)
    expect(report.has_col_encodings).to eq(false)
  end

  it 'should extract sort key' do
    schema_name = @config[:export_schema]

    # test normal
    table_name = "polizei_test_#{rand(1024)}"
    report = create_and_return_report(
      schema_name: schema_name,
      table_name: table_name,
      create_sql: "CREATE TABLE #{schema_name}.#{table_name}(id INT, txt VARCHAR) SORTKEY(id, txt)"
    )
    expect(report.sort_keys).to eq(['id', 'txt'])

    # test reversed
    table_name = "polizei_test_#{rand(1024)}"
    report = create_and_return_report(
      schema_name: schema_name,
      table_name: table_name,
      create_sql: "CREATE TABLE #{schema_name}.#{table_name}(id INT, txt VARCHAR) SORTKEY(txt, id)"
    )
    expect(report.sort_keys).to eq(['txt', 'id'])
  end

  it 'should extract dist key with style' do
    schema_name = @config[:export_schema]
    table_name = "polizei_test_#{rand(1024)}"
    report = create_and_return_report(
      schema_name: schema_name,
      table_name: table_name,
      create_sql: "CREATE TABLE #{schema_name}.#{table_name}(id INT, txt VARCHAR) DISTKEY(id)"
    )
    expect(report.dist_style).to eq('key')
    expect(report.dist_key).to eq('id')
  end

  it 'should extract even dist style' do
    schema_name = @config[:export_schema]
    table_name = "polizei_test_#{rand(1024)}"
    report = create_and_return_report(
      schema_name: schema_name,
      table_name: table_name,
      create_sql: "CREATE TABLE #{schema_name}.#{table_name}(id INT, txt VARCHAR) DISTSTYLE EVEN"
    )
    expect(report.dist_style).to eq('even')
  end

  it 'should extract all dist style' do
    schema_name = @config[:export_schema]
    table_name = "polizei_test_#{rand(1024)}"
    report = create_and_return_report(
      schema_name: schema_name,
      table_name: table_name,
      create_sql: "CREATE TABLE #{schema_name}.#{table_name}(id INT, txt VARCHAR) DISTSTYLE ALL"
    )
    expect(report.dist_style).to eq('all')
  end

  it 'should extract compound sort style' do
    schema_name = @config[:export_schema]
    table_name = "polizei_test_#{rand(1024)}"
    report = create_and_return_report(
      schema_name: schema_name,
      table_name: table_name,
      create_sql: "CREATE TABLE #{schema_name}.#{table_name}(id INT, txt VARCHAR) COMPOUND SORTKEY(id)"
    )
    expect(report.sort_style).to eq('compound')
  end

  it 'should extract compound sort style' do
    schema_name = @config[:export_schema]
    table_name = "polizei_test_#{rand(1024)}"
    report = create_and_return_report(
      schema_name: schema_name,
      table_name: table_name,
      create_sql: "CREATE TABLE #{schema_name}.#{table_name}(id INT, txt VARCHAR) INTERLEAVED SORTKEY(id)"
    )
    expect(report.sort_style).to eq('interleaved')
  end

  it 'should extract column encodings' do
    schema_name = @config[:export_schema]
    table_name = "polizei_test_#{rand(1024)}"
    report = create_and_return_report(
      schema_name: schema_name,
      table_name: table_name,
      create_sql: "CREATE TABLE #{schema_name}.#{table_name}(id INT ENCODE DELTA32K, txt VARCHAR)"
    )
    expect(report.has_col_encodings).to eq(true)
  end

  it 'should remove deleted tables' do
    schema_name = @config[:export_schema]
    table_name = "polizei_test_#{rand(1024)}"
    create_report(schema_name: schema_name, table_name: table_name)
    expect(Models::TableReport.where(schema_name: schema_name, table_name: table_name).exists?).to eq(true)
    create_report(schema_name: schema_name, table_name: table_name, donotcreate: true)
    expect(Models::TableReport.where(schema_name: schema_name, table_name: table_name).exists?).to eq(false)
  end

  it 'should create a report on all tables without arguments' do
    RSPool.with do |c|
      tbl_count = c.exec("select count(*) as cnt
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where trim(n.nspname) not in ('pg_catalog', 'pg_toast', 'information_schema')")[0]['cnt'].to_i
      create_report(schema_name: nil, table_name: nil, donotcreate: true)
      expect(Models::TableReport.count).to eq(tbl_count)
    end
  end
end

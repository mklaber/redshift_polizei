require_relative '../../spec_helper'

describe Jobs::TableStructureExportJob do
  def schema_name
    PG::Connection.quote_ident(@config[:test_schema])
  end
  def new_table_name
    "polizei_schema_test_#{rand(1024)}"
  end

  def create_table(sql)
    RSPool.with { |c| c.exec(sql) }
  end

  def retrieve_schema(table_name, options={})
    RSPool.with do |c|
      begin
        aws_path = Jobs::TableStructureExportJob.run(1, 1, {
          schema_name: @config[:test_schema],
          table_name: table_name,
          nospacer: true,
          nomail: true
        }.merge(options))
        s3_obj = AWS::S3.new.buckets[aws_path[:bucket]].objects[aws_path[:key]]
        return s3_obj.read
      ensure
        c.exec("DROP TABLE IF EXISTS #{@config[:test_schema]}.#{table_name}")
        s3_obj.delete unless s3_obj.nil?
      end
    end
  end

  it 'should create schema from basic table' do
    table_name = new_table_name
    table_sql = "CREATE TABLE #{schema_name}.\"#{table_name}\"(\n\t\"id\" integer NULL ENCODE raw\n)\nDISTSTYLE all";
    create_table(table_sql)
    schema_sql = retrieve_schema(table_name)
    expect(schema_sql).to eq(table_sql + "\n;")
  end

  it 'should create schema from basic table with multiple columns' do
    table_name = new_table_name
    table_sql = "CREATE TABLE #{schema_name}.\"#{table_name}\"(\n\t\"id\" integer NULL ENCODE raw,\n\t\"id2\" integer NULL ENCODE raw\n)\nDISTSTYLE all";
    create_table(table_sql)
    schema_sql = retrieve_schema(table_name)
    expect(schema_sql).to eq(table_sql + "\n;")
  end

  it 'should create schema from basic table with varchar length-restricted column' do
    table_name = new_table_name
    table_sql = "CREATE TABLE #{schema_name}.\"#{table_name}\"(\n\t\"txt\" character varying(42) NULL ENCODE raw\n)\nDISTSTYLE all";
    create_table(table_sql)
    schema_sql = retrieve_schema(table_name)
    expect(schema_sql).to eq(table_sql + "\n;")
  end

  it 'should create schema from basic table with restricted numeric column' do
    table_name = new_table_name
    table_sql = "CREATE TABLE #{schema_name}.\"#{table_name}\"(\n\t\"id\" numeric(4, 2) NULL ENCODE raw\n)\nDISTSTYLE all";
    create_table(table_sql)
    schema_sql = retrieve_schema(table_name)
    expect(schema_sql).to eq(table_sql + "\n;")
  end

  it 'should create schema from basic table with not null column' do
    table_name = new_table_name
    table_sql = "CREATE TABLE #{schema_name}.\"#{table_name}\"(\n\t\"id\" integer NOT NULL ENCODE raw\n)\nDISTSTYLE all";
    create_table(table_sql)
    schema_sql = retrieve_schema(table_name)
    expect(schema_sql).to eq(table_sql + "\n;")
  end

  it 'should create schema with default value column' do
    table_name = new_table_name
    table_sql = "CREATE TABLE #{schema_name}.\"#{table_name}\"(\n\t\"id\" integer NULL DEFAULT 21 ENCODE raw\n)\nDISTSTYLE all";
    create_table(table_sql)
    schema_sql = retrieve_schema(table_name)
    expect(schema_sql).to eq(table_sql + "\n;")
  end

  it 'should create schema with identity column' do
    table_name = new_table_name
    table_sql = "CREATE TABLE #{schema_name}.\"#{table_name}\"(\n\t\"id\" integer NULL IDENTITY(42,21) ENCODE raw\n)\nDISTSTYLE all";
    create_table(table_sql)
    schema_sql = retrieve_schema(table_name)
    expect(schema_sql).to eq(table_sql + "\n;")
  end

  it 'should create schema with encoded column' do
    table_name = new_table_name
    table_sql = "CREATE TABLE #{schema_name}.\"#{table_name}\"(\n\t\"id\" integer NULL ENCODE lzo\n)\nDISTSTYLE all";
    create_table(table_sql)
    schema_sql = retrieve_schema(table_name)
    expect(schema_sql).to eq(table_sql + "\n;")
  end

  it 'should create schema from basic table with custom dist style' do
    table_name = new_table_name
    table_sql = "CREATE TABLE #{schema_name}.\"#{table_name}\"(\n\t\"id\" integer NULL ENCODE raw\n)\nDISTSTYLE key\nDISTKEY (\"id\")";
    create_table(table_sql)
    schema_sql = retrieve_schema(table_name)
    expect(schema_sql).to eq(table_sql + "\n;")
  end

  it 'should create schema from basic table with sort keys' do
    table_name = new_table_name
    table_sql = "CREATE TABLE #{schema_name}.\"#{table_name}\"(\n\t\"id\" integer NULL ENCODE raw,\n\t\"id2\" integer NULL ENCODE raw\n)\nDISTSTYLE all\nSORTKEY (\"id2\", \"id\")";
    create_table(table_sql)
    schema_sql = retrieve_schema(table_name)
    expect(schema_sql).to eq(table_sql + "\n;")
  end

  it 'should create schema from basic table with unique constraint' do
    table_name = new_table_name
    table_sql = "CREATE TABLE #{schema_name}.\"#{table_name}\"(\n\t\"id\" integer NULL ENCODE raw,\n\tUNIQUE (\"id\")\n)\nDISTSTYLE all";
    create_table(table_sql)
    schema_sql = retrieve_schema(table_name)
    expect(schema_sql).to eq(table_sql + "\n;")
  end

  it 'should create schema from basic table with primary key' do
    table_name = new_table_name
    table_sql = "CREATE TABLE #{schema_name}.\"#{table_name}\"(\n\t\"id\" integer NOT NULL ENCODE raw,\n\tPRIMARY KEY (\"id\")\n)\nDISTSTYLE all";
    create_table(table_sql)
    schema_sql = retrieve_schema(table_name)
    expect(schema_sql).to eq(table_sql + "\n;")
  end

  it 'should create schema from basic table with foreign key' do
    begin
      table_name = new_table_name
      table_name2 = new_table_name
      create_table("CREATE TABLE #{schema_name}.\"#{table_name2}\"(\n\t\"id\" integer NULL UNIQUE ENCODE raw\n)\nDISTSTYLE all")
      table_sql = "CREATE TABLE #{schema_name}.\"#{table_name}\"(\n\t\"id\" integer NULL ENCODE raw,\n\tFOREIGN KEY (\"id\") REFERENCES #{schema_name}.\"#{table_name2}\" (\"id\")\n)\nDISTSTYLE all";
      create_table(table_sql)
      schema_sql = retrieve_schema(table_name)
      expect(schema_sql).to eq(table_sql + "\n;")
    ensure
      RSPool.with { |c| c.exec("DROP TABLE IF EXISTS #{@config[:test_schema]}.#{table_name2}") }
    end
  end
end

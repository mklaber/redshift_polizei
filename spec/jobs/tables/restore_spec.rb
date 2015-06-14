require_relative '../../spec_helper'

describe Jobs::RestoreJob do

  #
  # Runs a RestoreJob with the specified options and returns the job run.
  #
  def run_restore(options={})
    return Jobs::RestoreJob.enqueue('UserId',
                                    {
                                        db: {
                                            connection_id: @connection_id,
                                            username: @config[:archive_username],
                                            password: @config[:archive_password],
                                            schema: @config[:archive_schema],
                                            table: nil
                                        },
                                        s3: {
                                            access_key_id: @config[:access_key_id],
                                            secret_access_key: @config[:secret_access_key],
                                            bucket: @config[:archive_bucket],
                                            prefix: nil
                                        },
                                        copy: {
                                            gzip: false,
                                            removequotes: true,
                                            escape: true,
                                            null_as: 'NULL'
                                        },
                                        mail: {nomailer: true}
                                    }.deep_merge(options))
  end

  it 'should fail if ddl file does not exist' do
    @bucket.objects[@ddl_file].delete
    r = run_restore({db: {table: @table}, s3: {prefix: @archive_prefix}})
    expect(r.failed?).to eq(true)
    expect(r.error).to eq("S3 ddl_file #{@config[:archive_bucket]}/#{@archive_prefix}ddl does not exist!")
  end

  it 'should fail if manifest file does not exist' do
    @bucket.objects[@manifest_file].delete
    r = run_restore({db: {table: @table}, s3: {prefix: @archive_prefix}})
    expect(r.failed?).to eq(true)
    expect(r.error).to eq("S3 manifest_file #{@config[:archive_bucket]}/#{@manifest_file} does not exist!")
  end

  it 'should fail if ddl file does not contain valid DDL' do
    ddl_text = <<-TEXT
      CREATE TABLE "#{@schema}"."#{@table}FAKE"(id INT, txt VARCHAR);
    TEXT
    @bucket.objects[@ddl_file].write(ddl_text)
    r = run_restore({db: {table: @table}, s3: {prefix: @archive_prefix}})
    expect(r.failed?).to eq(true)
    expect(r.error).to eq("S3 ddl_file #{@config[:archive_bucket]}/#{@ddl_file} must contain a single valid CREATE TABLE statement!")
  end

  it 'should properly restore a table' do
    # RestoreJob should succeed.
    r = run_restore({db: {table: @table}, s3: {prefix: @archive_prefix}})
    expect(r.failed?).to eq(false)
    expect(r.result['schema']).to eq(@schema)
    expect(r.result['table']).to eq(@table)

    # Ensure restored table exists in Redshift.
    # Ensure redshift table was dropped.
    res = @conn.exec("SELECT * FROM information_schema.tables WHERE table_schema = '#{@schema}' AND table_name = '#{@table}'")
    expect(res.ntuples).to eq(1)
    # Ensure restored table holds the archived data.
    res = @conn.exec("SELECT * FROM #{@full_table_name} ORDER BY id")
    expect(res.ntuples).to eq(4)
    expect(res[0]['id']).to eq('0')
    expect(res[0]['txt']).to eq('hello')
    expect(res[1]['id']).to eq('1')
    expect(res[1]['txt']).to eq('privyet')
    expect(res[2]['id']).to eq('2')
    expect(res[2]['txt']).to be_nil
    expect(res[3]['id']).to eq('3')
    expect(res[3]['txt']).to eq('|')

    # Ensure TableArchive entry was destroyed.
    expect(Models::TableArchive.find_by(schema_name: @schema, table_name: @table)).to be_nil
  end

  before(:each) do
    @connection_id = 'redshift_test'
    @schema = @config[:archive_schema]
    @table = "restore_test_#{Time.now.to_i}_#{rand(1024)}"
    @full_table_name = "#{@schema}.#{@table}"

    # Write sample ddl, manifest, and data files to S3.
    @bucket = AWS::S3.new.buckets[@config[:archive_bucket]]
    @archive_prefix = "test/#{@full_table_name}"
    @ddl_file = "#{@archive_prefix}ddl"
    ddl_text = <<-TEXT
      CREATE TABLE "#{@schema}"."#{@table}"(id INT, txt VARCHAR);
    TEXT
    @bucket.objects[@ddl_file].write(ddl_text)
    @data_file= "#{@archive_prefix}-0000_part_00"
    data_text = <<-TEXT
"0"|"hello"
"1"|"privyet"
"2"|"NULL"
"3"|"|"
  TEXT
    # data_text = "0|hello\n1|privyet\n|"
    @bucket.objects[@data_file].write(data_text)
    @manifest_file = "#{@archive_prefix}manifest"
    manifest_text = <<-JSON
      {"entries":[{"url":"s3://#{@config[:archive_bucket]}/#{@data_file}"}]}
    JSON
    @bucket.objects[@manifest_file].write(manifest_text)

    # Create TableArchive entry.
    table_archive = Models::TableArchive.create(schema_name: @schema, table_name: @table,
                                                archive_bucket: @config[:archive_bucket],
                                                archive_prefix: @archive_prefix)
    table_archive.save

    @conn = RSUtil.dedicated_connection(connection_id: @connection_id,
                                        username: @config[:archive_username],
                                        password: @config[:archive_password])
  end

  after(:each) do
    # Remove any TableArchive references.
    tbl = Models::TableArchive.find_by(schema_name: @schema, table_name: @table)
    tbl.destroy unless tbl.nil?
    # Remove extra TableReports references.
    tbl = Models::TableReport.find_by(schema_name: @schema, table_name: @table)
    tbl.destroy unless tbl.nil?
    # Drop test redshift table.
    @conn.exec("DROP TABLE IF EXISTS #{@full_table_name}")
    # Clean up S3 files.
    @bucket.objects.with_prefix("test/#{@full_table_name}").delete_all
  end

end

require_relative '../../spec_helper'

describe Jobs::RecomputeEncodingJob do

  #
  # Runs an RecomputeEncodingJob with the specified options and returns the job run.
  #
  def run_encoding(options={})
    return Jobs::RecomputeEncodingJob.enqueue('UserId', options)
  end

  #
  # helper function to keep track of what options where used
  #
  def merge_options(options={})
    return {
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
        redshift: {
            allowoverwrite: true,
            gzip: false,
            quotes: true,
            escape: true,
            null_as: 'NULL'
        },
        mail: {nomailer: true}
    }.deep_merge(options)
  end

  it 'should succeed in removing unnecessary encodings' do
    options = merge_options({db: {table: @table},
                             s3: {prefix: @full_table_name}})
    result = run_encoding(options)
    expect(result.failed?).to(eq(false), "Error: #{result.error}")
    expect(TableUtils.has_column_encodings(@conn, {schema_name: @schema, table_name: @table})).to eq({})
  end

  before(:each) do
    @connection_id = 'redshift_test'
    @schema = @config[:archive_schema]
    @table = "encoding_test_#{Time.now.to_i}_#{rand(1024)}"
    @full_table_name = "#{@schema}.#{@table}"
    @archive_prefix = "test/#{@full_table_name}"
    @conn = RSUtil.dedicated_connection(connection_id: @connection_id,
                                        username: @config[:archive_username],
                                        password: @config[:archive_password])
    create_sql = <<-SQL
        CREATE TABLE #{@full_table_name}(id INT ENCODE LZO, txt VARCHAR ENCODE LZO);
        INSERT INTO #{@full_table_name} VALUES (0, 'hello'), (1, 'privyet'), (2, null);
    SQL
    @conn.exec(create_sql)
    @bucket = AWS::S3.new.buckets[@config[:archive_bucket]]
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
    # Clean up S3 archive files.
    @bucket.objects.with_prefix(@archive_prefix).delete_all
  end

end

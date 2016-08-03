require_relative '../../spec_helper'

describe Jobs::RegenerateTableJob do

  #
  # Runs an RegenerateTableJob with the specified options and returns the job run.
  #
  def run_regenerate(options={})
    return Jobs::RegenerateTableJob.enqueue('UserId', options)
  end

  #
  # helper function to keep track of what options where used
  #
  def merge_options(options={})
    return {
        db: {
            connection_id: $connection_id,
            username: @config[:rs_user],
            password: @config[:rs_password],
            schema: @config[:schema],
            table: nil,  # specify in options
            is_test: true
        },
        s3: {
            access_key_id: @config[:aws_access_key_id],
            secret_access_key: @config[:aws_secret_access_key],
            bucket: @config[:bucket],
            prefix: nil # specify in options
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
    options = merge_options({
                                db: {
                                    table: @table,
                                    auto_encode: true
                                },
                                s3: {
                                    prefix: @full_table_name
                                }
                            })
    result = run_regenerate(options)
    expect(result.failed?).to(eq(false), "Error: #{result.error}")
    expect(TableUtils.has_column_encodings($conn, {schema_name: @schema, table_name: @table})).to eq({})
  end

  it 'should succeed in adding a new dist key' do
    dist_key = 'id'
    options = merge_options({
                                db: {
                                    table: @table,
                                    diststyle_override: 'KEY',
                                    distkey_override: dist_key
                                },
                                s3: {
                                    prefix: @full_table_name
                                }
                            })
    result = run_regenerate(options)
    expect(result.failed?).to(eq(false), "Error: #{result.error}")
    keys = TableUtils.get_sort_and_dist_keys($conn, {schema_name: @schema, table_name: @table})[@full_table_name]
    expect(keys['dist_key']).to eq(dist_key)
  end

  it 'should succeed in adding a new sort key' do
    sort_keys = ['id']
    options = merge_options({
                                db: {
                                    table: @table,
                                    sortstyle_override: '',
                                    sortkeys_override: sort_keys
                                },
                                s3: {
                                    prefix: @full_table_name
                                }
                            })
    result = run_regenerate(options)
    expect(result.failed?).to(eq(false), "Error: #{result.error}")
    keys = TableUtils.get_sort_and_dist_keys($conn, {schema_name: @schema, table_name: @table})[@full_table_name]
    expect(keys['sort_keys']).to eq(sort_keys)
  end

  it 'should fail with an invalid dist key' do
    dist_key = 'nonExistentKey'
    options = merge_options({
                                db: {
                                    table: @table,
                                    diststyle_override: 'KEY',
                                    distkey_override: dist_key
                                },
                                s3: {
                                    prefix: @full_table_name
                                }
                            })
    result = run_regenerate(options)
    expect(result.failed?).to eq(true)
    expect(result.error).to eq("Distribution key nonExistentKey not found. Keys Available: [\"id\", \"txt\"]")
  end

  it 'should fail with an invalid sort keys' do
    sort_keys = %w{id nonExistentKey}
    options = merge_options({
                                db: {
                                    table: @table,
                                    sortstyle_override: '',
                                    sortkeys_override: sort_keys
                                },
                                s3: {
                                    prefix: @full_table_name
                                }
                            })
    result = run_regenerate(options)
    expect(result.failed?).to eq(true)
    expect(result.error).to eq("Sort key nonExistentKey not found. Keys Available: [\"id\", \"txt\"]")
  end

  before(:each) do
    @schema = @config[:schema]
    @table = "encoding_test_#{Time.now.to_i}_#{rand(1024)}"
    @full_table_name = "#{@schema}.#{@table}"
    @archive_prefix = "test/#{@full_table_name}"
    create_sql = <<-SQL
        CREATE TABLE #{@full_table_name}(id INT ENCODE LZO, txt VARCHAR ENCODE LZO);
        INSERT INTO #{@full_table_name} VALUES (0, 'hello'), (1, 'privyet'), (2, null);
    SQL
    $conn.exec(create_sql)
    @bucket = AWS::S3.new.buckets[@config[:bucket]]
  end

  after(:each) do
    # Remove any TableArchive references.
    tbl = Models::TableArchive.find_by(schema_name: @schema, table_name: @table)
    tbl.destroy unless tbl.nil?
    # Remove extra TableReports references.
    tbl = Models::TableReport.find_by(schema_name: @schema, table_name: @table)
    tbl.destroy unless tbl.nil?
    # Drop test redshift table.
    $conn.exec("DROP TABLE IF EXISTS #{@full_table_name}")
    # Clean up S3 archive files.
    @bucket.objects.with_prefix(@archive_prefix).delete_all
  end

end

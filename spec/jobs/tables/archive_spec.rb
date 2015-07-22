require_relative '../../spec_helper'

describe Jobs::ArchiveJob do

  #
  # Runs an ArchiveJob with the specified options and returns the job run.
  #
  def run_archive(options={})
    return Jobs::ArchiveJob.enqueue('UserId', options)
  end

  #
  # Checks if the result of an ArchiveJob fully succeeded.
  #
  def check_success(result, options)
    ddl_s3_key = "#{options[:s3][:prefix]}ddl"
    manifest_s3_key = "#{options[:s3][:prefix]}manifest"
    expect(result.failed?).to(eq(false), "Error: #{result.error}")
    expect(result.result['manifest_file']).to eq("s3://#{options[:s3][:bucket]}/#{manifest_s3_key}")
    expect(result.result['ddl_file']).to eq("s3://#{options[:s3][:bucket]}/#{ddl_s3_key}")

    # Ensure S3 ddl and manifest files exist.
    bucket = AWS::S3.new.buckets[options[:s3][:bucket]]
    expect(bucket.objects[ddl_s3_key].exists?).to eq(true)
    expect(bucket.objects[manifest_s3_key].exists?).to eq(true)

    # Ensure TableArchive entry was created.
    schema = options[:db][:schema]
    table = options[:db][:table]
    expect(Models::TableArchive.find_by(schema_name: schema, table_name: table)).not_to be_nil

    # Ensure redshift table was preserved or dropped depending on skip_drop option
    res = @conn.exec("SELECT * FROM information_schema.tables WHERE table_schema = '#{schema}' AND table_name = '#{table}'")
    expect(res.ntuples).to eq(options[:db][:skip_drop] ? 1 : 0)
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
        unload: {
            allowoverwrite: true,
            gzip: false,
            addquotes: true,
            escape: true,
            null_as: 'NULL'
        },
        mail: {nomailer: true}
    }.deep_merge(options)
  end

  it 'should fail if TableArchive entry already exists' do
    table_archive = Models::TableArchive.create(schema_name: @schema, table_name: @table,
                                                archive_bucket: '',
                                                archive_prefix: '')
    table_archive.save
    options = merge_options({db: {table: @table}, s3: {prefix: @archive_prefix}})
    r = run_archive(options)
    expect(r.failed?).to eq(true)
    expect(r.error).to eq('Archive entry already exists for this table!')
  end

  it 'should succeed with default settings' do
    options = merge_options({db: {table: @table},
                             s3: {prefix: @archive_prefix}})
    check_success(run_archive(options), options)
  end

  it 'should succeed with skip_drop enabled' do
    options = merge_options({db: {table: @table, skip_drop: true},
                             s3: {prefix: @archive_prefix}})
    check_success(run_archive(options), options)
  end

  it 'should succeed with auto_encode enabled' do
    options = merge_options({db: {table: @table, auto_encode: true},
                             s3: {prefix: @archive_prefix}})
    check_success(run_archive(options), options)
  end

  it 'should succeed on a table with a foreign key reference to another table' do
    table2 = "archive_test_#{Time.now.to_i}_#{rand(1024)}"
    full_table_name2 = "#{@schema}.#{table2}"
    extra_sql = <<-SQL
        CREATE TABLE #{full_table_name2}(id INT PRIMARY KEY);
        INSERT INTO #{full_table_name2} VALUES (0), (1), (2);
        ALTER TABLE #{@full_table_name}
          ADD FOREIGN KEY(id) REFERENCES #{full_table_name2}(id);
    SQL
    @conn.exec(extra_sql)
    options = merge_options({db: {table: @table, auto_encode: true},
                             s3: {prefix: @archive_prefix}})
    check_success(run_archive(options), options)
  end

  it 'should succeed on a table that another table has a reference to' do
    table2 = "archive_test_#{Time.now.to_i}_#{rand(1024)}"
    @full_table_name2 = "#{@schema}.#{table2}"
    extra_sql = <<-SQL
        CREATE TABLE #{@full_table_name2}
          (id INT REFERENCES #{@full_table_name}(id));
        INSERT INTO #{@full_table_name2} VALUES (0), (1), (2);
    SQL
    @conn.exec(extra_sql)
    options = merge_options({db: {table: @table, auto_encode: true}, s3: {prefix: @archive_prefix}})
    check_success(run_archive(options), options)
  end

  it 'should archive permissions correctly' do
    # change permissions
    change_owner_sql = "ALTER TABLE #{@full_table_name} OWNER TO \"#{@test_user}\""
    grant_group_sql = "GRANT INSERT, UPDATE, DELETE ON #{@full_table_name} TO GROUP \"#{@test_group}\""
    grant_user_sql = "GRANT SELECT, REFERENCES ON #{@full_table_name} TO \"#{@conn.user}\""
    @conn.exec(change_owner_sql)
    @conn.exec(grant_group_sql)
    @conn.exec(grant_user_sql)
    # run archive
    options = merge_options({db: {table: @table},
                             s3: {prefix: @archive_prefix}})
    check_success(run_archive(options), options)
    # check archived permissions
    sqls = AWS::S3.new.buckets[@config[:archive_bucket]].objects[@permissions_file].read.split(";\n")
    expect(sqls).to match_array([
      change_owner_sql, grant_group_sql, grant_user_sql,
      "GRANT SELECT, INSERT, UPDATE, DELETE, REFERENCES ON \"#{@schema}\".\"#{@table}\" TO \"#{@test_user}\""
    ])
  end

  it 'should archive table comments successfully' do
    add_cmt_sql = "COMMENT ON TABLE #{@full_table_name} IS 'test_comment_#{rand(1024)}'"
    @conn.exec(add_cmt_sql)
    options = merge_options({db: {table: @table, auto_encode: true}, s3: {prefix: @archive_prefix}})
    check_success(run_archive(options), options)
    # ensure ddl file contains the comment
    expect(@bucket.objects[@ddl_file].read).to include(add_cmt_sql)
  end

  before(:each) do
    @schema = @config[:archive_schema]
    @table = "archive_test_#{Time.now.to_i}_#{rand(1024)}"
    @table_with_schema = "#{@schema}.#{@table}"
    @full_table_name = "\"#{@schema}\".\"#{@table}\""
    @archive_prefix = "test/#{@table_with_schema}"
    @permissions_file = "#{@archive_prefix}permissions.sql"
    @ddl_file = "#{@archive_prefix}ddl"

    create_sql = <<-SQL
        CREATE TABLE #{@full_table_name}(id INT PRIMARY KEY, txt VARCHAR);
        INSERT INTO #{@full_table_name} VALUES (0, 'hello'), (1, 'privyet'), (2, null);
    SQL
    @conn.exec(create_sql)
    @bucket = AWS::S3.new.buckets[@config[:archive_bucket]]
  end

  after(:each) do
    # Remove any TableArchive references.
    tbl = Models::TableArchive.find_by(schema_name: @schema, table_name: @table)
    tbl.destroy unless tbl.nil?
    # Drop test redshift table.
    @conn.exec("DROP TABLE IF EXISTS #{@full_table_name} CASCADE; DROP TABLE IF EXISTS #{@full_table_name2} CASCADE;")
    # Clean up S3 archive files.
    @bucket.objects.with_prefix(@archive_prefix).delete_all
  end
end

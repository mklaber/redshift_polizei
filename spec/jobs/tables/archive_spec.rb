require_relative '../../spec_helper'

describe Jobs::ArchiveJob do
  
  #
  # Runs an ArchiveJob with the specified options and returns the job run.
  #
  def run_archive(options={})
    return Jobs::ArchiveJob.enqueue('UserId',
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
                                            archive_bucket: @config[:archive_bucket],
                                            archive_prefix: nil
                                        },
                                        unload: {
                                            allowoverwrite: true,
                                            gzip: false,
                                            addquotes: true,
                                            escape: true,
                                            null_as: 'NULL'
                                        },
                                        mail: {nomailer: true}
                                    }.deep_merge(options))
  end

  it 'should fail if TableArchive entry already exists' do
    table_archive = Models::TableArchive.create(schema_name: @schema, table_name: @table,
                                                archive_bucket: '',
                                                archive_prefix: '')
    table_archive.save
    r = run_archive({db: {table: @table}, s3: {archive_prefix: @full_table_name}})
    expect(r.failed?).to eq(true)
    expect(r.error).to eq('Archive entry already exists for this table!')
  end

  it 'should properly archive a table' do
    # In case any previous tests wrote a record already.
    tbl = Models::TableArchive.find_by(schema_name: @schema, table_name: @table)
    tbl.destroy unless tbl.nil?

    # ArchiveJob should succeed.
    ddl_s3_key = "#{@full_table_name}ddl"
    manifest_s3_key = "#{@full_table_name}manifest"
    r = run_archive({db: {table: @table}, s3: {archive_prefix: @full_table_name}})
    expect(r.failed?).to eq(false)
    expect(r.result['ddl_file']).to eq("s3://#{@config[:archive_bucket]}/#{ddl_s3_key}")
    expect(r.result['manifest_file']).to eq("s3://#{@config[:archive_bucket]}/#{manifest_s3_key}")

    # Ensure S3 ddl and manifest files exist.
    expect(@bucket.objects[ddl_s3_key].exists?).to eq(true)
    expect(@bucket.objects[manifest_s3_key].exists?).to eq(true)
    # Ensure S3 files hold the table data.
    data = []
    AWS::S3.new.buckets[@config[:archive_bucket]].objects.each do |obj|
      if obj.key =~ /#{Regexp.quote(@full_table_name)}[0-9]*_part_[0-9]*/
        obj.read.split("\n").each do |line|
          d = line.split('|')
          data << line.split('|') unless d.empty?
        end
      end
    end
    expect(data.sort_by! { |obj| obj[0] }).to eq([%w{"0" "hello"}, %w{"1" "privyet"}, %w{"2" "NULL"}])

    # Ensure TableArchive entry was created.
    expect(Models::TableArchive.find_by(schema_name: @schema, table_name: @table)).not_to be_nil

    # Ensure redshift table was dropped.
    res = @conn.exec("SELECT * FROM information_schema.tables WHERE table_schema = '#{@schema}' AND table_name = '#{@table}'")
    expect(res.ntuples).to eq(0)
  end

  before(:all) do
    @connection_id = 'redshift_test'
    @schema = @config[:archive_schema]
    @table = "archive_test_#{Time.now.to_i}_#{rand(1024)}"
    @full_table_name = "#{@schema}.#{@table}"
    @conn = RSUtil.dedicated_connection(connection_id: @connection_id,
                                        username: @config[:archive_username],
                                        password: @config[:archive_password])
    create_sql = <<-SQL
        CREATE TABLE #{@full_table_name}(id INT, txt VARCHAR);
        INSERT INTO #{@full_table_name} VALUES (0, 'hello'), (1, 'privyet'), (2, null);
    SQL
    @conn.exec(create_sql)
    @bucket = AWS::S3.new.buckets[@config[:archive_bucket]]
  end

  after(:all) do
    # Remove any TableArchive references.
    tbl = Models::TableArchive.find_by(schema_name: @schema, table_name: @table)
    tbl.destroy unless tbl.nil?
    # Drop test redshift table.
    @conn.exec("DROP TABLE IF EXISTS #{@full_table_name}")
    # Clean up S3 archive files.
    @bucket.objects.with_prefix(@full_table_name).delete_all
  end

end

require_relative '../spec_helper'

describe Jobs::PolizeiExportJob do
  #
  # runs an export and returns the job run
  #
  def run_export(model_options={}, enqueue_options={}, options={})
    connection_id = 'redshift_test'
    c = PGUtil.dedicated_connection(connection_id: connection_id, username: @config[:export_username], password: @config[:export_password])
    table = "#{@config[:export_schema]}.polizei_test_#{rand(1024)}"
    c.exec("CREATE TABLE #{table}(id INT, txt VARCHAR)")
    c.exec("INSERT INTO #{table} VALUES(0, 'null')")
    c.exec("INSERT INTO #{table} VALUES(1, 'eins')")
    run = Models::ExportJob.create!({
      name: table,
      user: Models::User.first,
      public: false,
      query: "SELECT * FROM #{table} order by id;",
      export_format: 'csv',
      export_options: { delimiter: '|' }
    }.merge(model_options)).enqueue(enqueue_options[:user] || Models::User.first, @config[:export_username], @config[:export_password], { s3: {
      bucket: @config[:export_bucket]
    }}.merge(enqueue_options))
  ensure
    AWS::S3.new.buckets[@config[:export_bucket]].objects[run.filename].delete unless options[:donotdelete]
    c.exec("DROP TABLE IF EXISTS #{table}")
    c.close
  end

  #
  # runs an export and returns the csv string from S3
  #
  def run_export_and_return_string(model_options={}, enqueue_options={}, options={})
    run = run_export(model_options, enqueue_options, options.merge(donotdelete: true))
    return nil if run.failed?
    s3_obj = nil
    csv = nil
    begin
      s3_obj = AWS::S3.new.buckets[@config[:export_bucket]].objects[run.filename]
      csv = s3_obj.read
    ensure
      s3_obj.delete
    end
    csv
  end

  it 'should export to pipe-delimited csv' do
    expect(run_export_and_return_string).to eq("0|null\n1|eins\n")
  end

  it 'should send a success email' do
    user = Models::User.first
    run_export({}, { user: user })
    open_last_email
    expect(current_email).to deliver_to(user.email)
    expect(current_email).to have_subject(/succeeded/)
    expect(current_email).to have_body_text(/succeeded/)
  end

  it 'should fail with invalid query' do
    expect(run_export({
      query: "SELECT * FROM #{@config[:export_schema]}.polizei_test_invalid order by id;"
    }).failed?).to eq(true)
  end

  it 'should send failure email' do
    user = Models::User.first
    expect(run_export({
      query: "SELECT * FROM #{@config[:export_schema]}.polizei_test_invalid order by id;"
    }, { user: user }).failed?).to eq(true)

    open_last_email
    expect(current_email).to deliver_to(user.email)
    expect(current_email).to cc_to(Sinatra::Configurations.polizei('job_failure_cc'))
    expect(current_email).to bcc_to(Sinatra::Configurations.polizei('job_failure_bcc'))
    expect(current_email).to have_subject(/failed/)
    expect(current_email).to have_body_text(/failed/)
  end
end

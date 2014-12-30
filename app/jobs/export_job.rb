require './app/main'

TIMEOUT = 5.0 # secs
FETCH_SIZE = 10000 # num of rows

module Jobs
  class ExportJob < Base
    def self.model
      Models::ExportJob
    end

    def run(job_id, user_id, options={})
      super(job_id, user_id, options)
      job = Models::ExportJob.find(job_id)
      user = Models::User.find(user_id)
      base_connection_id = "redshift_#{Sinatra::Application.environment}".to_sym
      job_name = job[:name].gsub(/\s+/, '').camelize
      time = Time.now.utc.strftime('%Y_%m_%dT%H_%M_%S_%LZ')
      export_id = "polizei_export_#{job.id.to_i}_#{job_name}_#{user.id}_#{user.name}_#{time}"
      csv_name = "#{export_id}.csv"
      s3_bucket = AWSConfig['export_bucket']
      s3_object = csv_name

      begin
        # database reader, streams rows without loading everything in memory
        db_reader = CSVStreams::ActiveRecordCustomConnectionCursorReader.new(
          export_id,
          job[:query],
          base_connection_id,
          options[:redshift_username],
          options[:redshift_password],
          fetch_size: FETCH_SIZE
        )

        # csv reader, transforms database rows to csv
        csv_reader = CSVStreams::CSVRecordHashReader.new(csv_name, db_reader,
          delimiter: job['export_options']['delimiter'],
          include_headers: job['export_options']['include_header'])

        # stream write to S3 from csv reader
        s3writer = CSVStreams::S3Writer.new(s3_bucket, s3_object)
        s3writer.write_from(csv_reader)

        puts ActionMailer::Base.delivery_method
        puts ActionMailer::Base.smtp_settings
        Mailers::ExportJob.success_email(job_id, s3writer.public_url).deliver_now

        # everything is done, remove the job
        done(url: s3writer.public_url)
      rescue => e
        # error occurred
        failed(error: e.message, backtrace: e.backtrace.join("\n "))
        Mailers::ExportJob.failure_email(job_id, e).deliver_now
      end
    end
  end
end

if __FILE__ == $0
  Jobs::ExportJob.new({}).run(1, 1)
end

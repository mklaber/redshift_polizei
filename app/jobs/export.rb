require_relative '../main'

module Jobs
  ##
  # this just implements hooks to send emails for 'Desmond::ExportJob'
  # by inheriting from it
  #
  class PolizeiExportJob < Desmond::ExportJob
    include JobHelpers

    ##
    # in case of success
    #
    def success(job_run, job_id, user_id, options={})
      # TODO write test that link in email is accessible
      export_job = Models::ExportJob.find(job_id)
      dl_url = AWS::S3.new.buckets[job_run.result['bucket']].objects[job_run.result['key']].url_for(
        :read,
        expires: (7 * 86400),
        response_content_type: "application/octet-stream"
      ).to_s
      view_url = AWS::S3.new.buckets[job_run.result['bucket']].objects[job_run.result['key']].url_for(
        :read,
        expires: (7 * 86400)
      ).to_s
      subject = "Export '#{export_job.name}' succeeded"
      body = "Congrats! Your export '#{export_job.name}' succeeded.
The direct download for your file is here: #{dl_url}
You can view it in your browser by using this link: #{view_url}"

      to  = Models::User.find(user_id).email
      to += ", #{export_job.success_email}" unless export_job.success_email.nil?
      mail(to, subject, body, options.fetch('mail', {}))
    end

    ##
    # in case of error
    #
    def error(job_run, job_id, user_id, options={})
      export_job = Models::ExportJob.find(job_id)
      subject = "ERROR: Export '#{export_job.name}' failed"
      body = "Sorry, your export '#{export_job.name}' failed.
The following error description might be helpful: '#{job_run.error}'"

      mail_options = {
        cc: GlobalConfig.polizei('job_failure_cc'),
        bcc: GlobalConfig.polizei('job_failure_bcc')
      }.merge(options.fetch('mail', {}))
      # if it's a filtered exception we won't notify engineering
      if exception_filtered?(job_run.error, job_run.error_type)
        mail_options[:cc]  = nil
        mail_options[:bcc] = nil
      end
      to  = Models::User.find(user_id).email
      to += ", #{export_job.failure_email}" unless export_job.failure_email.nil?
      mail(to, subject, body, mail_options)
    end

    private

    ##
    # common sending code
    #
    def mail(to, subject, body, options={})
      pony_options = { to: to, subject: subject, body: body }.merge(options)
      Pony.mail(pony_options)
    end
  end
end

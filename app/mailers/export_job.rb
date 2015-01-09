module Mailers
  class ExportJob < ApplicationMailer
    def success_email(job_id, export_url)
      @job = Models::ExportJob.find(job_id)
      @s3url = export_url
      email_to = "#{@job.user.email}, #{@job.success_email}"
      PolizeiLogger.logger.debug "Sending export success mail to '#{email_to}'"
      mail(:to      => email_to,
           :subject => "Polizei export '#{@job.name}' succeeded") do |format|
              format.text
           end
    end

    def failure_email(job_id, error)
      @job = Models::ExportJob.find(job_id)
      @error = error
      email_to = "#{@job.user.email}, #{@job.failure_email}"
      PolizeiLogger.logger.debug "Sending export failure mail to '#{email_to}'"
      mail(:to      => email_to,
           :cc      => ActionMailer::Base.smtp_settings[:job_failure_cc],
           :bcc     => ActionMailer::Base.smtp_settings[:job_failure_bcc],
           :subject => "ERROR: Polizei export '#{@job.name}' failed") do |format|
              format.text
           end
    end
  end
end

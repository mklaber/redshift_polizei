module Mailers
  class ExportJob < ApplicationMailer
    def success_email(job_id, export_url)
      @job = Models::ExportJob.find(job_id)
      @s3url = export_url
      PolizeiLogger.logger.debug "Sending export success mail to '#{@job.success_email}'"
      mail(:to      => @job.success_email,
           :subject => "Polizei export '#{@job.name}' succeeded") do |format|
              format.text
           end
    end

    def failure_email(job_id, error)
      @job = Models::ExportJob.find(job_id)
      @error = error
      PolizeiLogger.logger.debug "Sending export failure mail to '#{@job.failure_email}'"
      mail(:to      => @job.failure_email,
           :cc      => ActionMailer::Base.smtp_settings[:job_failure_cc],
           :bcc     => ActionMailer::Base.smtp_settings[:job_failure_bcc],
           :subject => "ERROR: Polizei export '#{@job.name}' failed") do |format|
              format.text
           end
    end
  end
end

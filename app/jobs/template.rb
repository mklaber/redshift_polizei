require './app/main'

module Jobs
  class TemplateJob < Base
    def self.model
      Models::ExportJob # model describing the job in the database
    end

    def run(job_id, user_id, options={})
      # make sure to call super before running your job
      super(job_id, user_id, options)

      begin
        ActiveRecord::Base.transaction do
          # do the job
          raise 'Nothing'

          # everything is done, remove the job
          done({})
        end
      rescue => e
        # mark job as failed and remove it
        failed({ error: e.message, backtrace: e.backtrace.join("\n ") })
        raise e
      end
    end
  end
end

if __FILE__ == $0
  Jobs::TemplateJob.enqueue(1, 1)
  #Que::Job.work
end

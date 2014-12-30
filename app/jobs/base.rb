require './app/main'

Que.logger = PolizeiLogger.logger
Que.error_handler = proc do |error, job|
  PolizeiLogger.logger.exception error
end

module Jobs
  class Base < ::Que::Job
    attr_accessor :run_id

    # take care to keep the arguments in sync with the error handler above!
    def self.enqueue(job_id, user_id, options={})
      e = Models::JobRun.create(job_id: job_id, job_class: self.model.name, user_id: user_id, status: 'queued')
      # the run_id is passed in as an option, because in the synchronous job execution mode, the created job instance
      # is returned after the job was executed, so no JobRun instance would be accessible during execution of the job
      super(job_id, user_id, options.merge({ _run_id: e.id }))
    end

    def self.model
      raise NotImplementedError
    end

    def run(job_id, user_id, options={})
      self.run_id = options[:_run_id] # retrieve run_id from options and safe it in the instance
      Models::JobRun.find(self.run_id).update(status: 'running', executed_at: Time.now)
    end

    def failed(details={})
      delete_job(false, details)
    end

    def done(details={})
      delete_job(true, details)
    end

    private
      def delete_job(success, details={})
        status = 'done'
        status = 'failed' if not(success)
        destroy
        Models::JobRun.find(self.run_id).update(status: status, details: details)
      end
  end
end

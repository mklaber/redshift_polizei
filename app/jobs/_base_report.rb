require_relative '../main'

module Jobs
  class WaitTimeoutReached < StandardError
  end

  #
  # abstract base class for reports
  #
  module BaseReport
    def enqueue_and_wait(job_id, user_id, timeout=nil, options={})
      run = self.enqueue(job_id, user_id, options)
      completed = !run.wait_until_finished(timeout).nil?
      unless completed
        fail WaitTimeoutReached.new("Timeout reached while waiting for #{self.name}")
      end
      if run.done?
        return run.result
      else
        fail run.error
      end
    end
  end

  module BaseReportNoJobId
    def enqueue_and_wait(user_id, timeout=nil, options={})
      run = self.enqueue(user_id, options)
      completed = !run.wait_until_finished(timeout).nil?
      unless completed
        fail WaitTimeoutReached.new("Timeout reached while waiting for #{self.name}")
      end
      if run.done?
        return run.result
      else
        fail run.error
      end
    end
  end
end

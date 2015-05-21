require_relative '../main'

module Jobs
  # TODO newest desmond already does this
  class WaitTimeoutReached < StandardError
  end

  ##
  # module enabling working on background jobs in the background
  # and waiting for result in the foreground (blocks until job is done or timeout reached)
  #
  module BaseReport
    def enqueue_and_wait(job_id, user_id, timeout=nil, options={})
      fail ArgumentError, "timeout argument needs to be numeric, is '#{timeout}'" unless timeout.nil? || timeout.is_a?(Numeric)
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

  ##
  # see above, equivalent module if no job_id is used
  #
  module BaseReportNoJobId
    def enqueue_and_wait(user_id, timeout=nil, options={})
      fail ArgumentError, "timeout argument needs to be numeric, is '#{timeout}'" unless timeout.nil? || timeout.is_a?(Numeric)
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

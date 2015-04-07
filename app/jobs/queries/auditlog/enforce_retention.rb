module Jobs
  module Queries
    module AuditLog
      #
      # Job deleting old audit log queries locally
      #
      class EnforceRetention < Desmond::BaseJobNoJobId
        extend Jobs::BaseReportNoJobId
        
        def execute(job_id, user_id, options={})
          timestamp_now = Time.now.to_i
          retention_time = Models::AuditLogConfig.get.retention_period
          Models::Query.where('record_time < ?', timestamp_now - retention_time).destroy_all
          true # we don't want to return all queries
        end
      end
    end
  end
end
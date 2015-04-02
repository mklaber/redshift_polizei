module Jobs
  module Queries
    module AuditLog
      #
      # Job reclassifying local audit log queries
      #
      class Reclassify < Desmond::BaseJobNoJobId
        extend Jobs::BaseReportNoJobId

        def execute(job_id, user_id, options={})
          Models::Query.all.each do |q|
            q.update!(query_type: Models::Query.query_type(q.query))
          end
          true # we don't want to return all queries
        end
      end
    end
  end
end
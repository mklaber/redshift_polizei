module Jobs
  module Queries
    #
    # Job retrieving recent (running AND completed queries) which were executed after a given time,
    # specified with option :date
    #
    class Recent < Desmond::BaseJobNoJobId
      def execute(job_id, user_id, options={})
        fail 'No option :date given' if options[:date].nil? || !options[:date].respond_to?(:to_time)
        # this good be asynchronous, but we don't want to create job runs everytime and stuff
        running_queries = Jobs::Queries::Running.run(user_id, options)
        completed_queries = Jobs::Queries::Completed.run(user_id, options)

        (running_queries + completed_queries)
      end
    end
  end
end

module Jobs
  module Queries
    #
    # Job retrieving recent (not running queries) which were executed after a given time,
    # specified with option :date
    #
    class Completed < Desmond::BaseJobNoJobId
      def execute(job_id, user_id, options={})
        fail(ArgumentError, 'No option :date given') if options[:date].nil? || !options[:date].respond_to?(:to_time)
        date = options[:date].to_time.utc.strftime('%Y-%m-%d %H:%M:%S')


        queries = RSPool.with do |connection|
          connection_user = connection.user
          connection_user = '' if options[:nouserfilter]
          SQL.execute(connection, 'queries/completed', parameters: [connection_user, date])
        end
        # merge individual parts of long queries
        queries = QueryUtils.sequence_merge(queries)

        # type casting and some post-processing
        queries.each do |query|
          query['user_id']    = query['user_id'].to_i
          query['status']     = 'Completed'
          query['pid']        = query['pid'].to_i
          query['suspended']  = false
          query['start_time'] = DateTime.parse(query['start_time']).to_time.to_i
          query['end_time']   = DateTime.parse(query['end_time']).to_time.to_i
          query['query'].strip!
        end
      end
    end
  end
end

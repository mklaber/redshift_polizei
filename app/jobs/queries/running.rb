module Jobs
  module Queries
    #
    # Job retrieving currently running queries
    #
    class Running < Desmond::BaseJobNoJobId
      def execute(job_id, user_id, options={})
        queries = RSPool.with do |connection|
          connection_user = connection.user
          connection_user = '' if options[:nouserfilter]
          sql = SQL.load('queries/running', parameters: connection_user)
          unless options[:table_overwrite].blank?
            sql.gsub!('rdsdb', '') # writing code for tests ... -.-
            sql.gsub!('svv_query_inflight', options[:table_overwrite])
          end
          SQL.execute_raw(connection, sql)
        end
        queries = QueryUtils.sequence_merge(queries)

        # long queries are returned with multiple rows, so we'll need to join them
        queries.each do |query|
          query['user_id']    = query['user_id'].to_i
          query['status']     = 'Running'
          query['pid']        = query['pid'].to_i
          query['suspended']  = (query['suspended'].to_i != 0)
          query['start_time'] = DateTime.parse(query['start_time']).to_time.to_i
          query['end_time']   = nil
          query['query'].strip!
          query.delete('sequence')
          query.delete('query_id')
        end
      end
    end
  end
end

module Jobs
  module Queries
    module AuditLog
      #
      # Job retrieving queries from the local audit log
      # options:
      # - selects: boolean whether to include select queries
      # - start: number at which offset to retrieve
      # - length: number of queries to return
      # - order: sort by column: 0 => 'record_time', 1 => 'user', 2 => 'xid', 3 => 'query'
      # - orderdir: 'asc' or 'desc' sorting direaction?
      # - search: string to search for (in username and query text)
      #
      class Get < Desmond::BaseJobNoJobId
        def execute(job_id, user_id, options={})
          # parse options
          fail(ArgumentError, 'option :selects must be given') if options[:selects].nil?
          fail(ArgumentError, 'option :start must be given') if options[:start].nil?
          fail(ArgumentError, 'option :length must be given') if options[:length].nil?
          order    = 0
          orderdir = 'desc'
          selects  = !!options[:selects]
          start    = options[:start].to_i
          length   = options[:length].to_i
          order    = options[:order].to_i if options.has_key?(:order)
          orderdir = options[:orderdir] if options.has_key?(:orderdir)
          search   = options[:search]

          # q_query is the filter query
          q_query = Models::Query
          q_query = q_query.where(query_type: 1) if not selects
          # filter by search query
          unless search.blank?
            q_query = q_query.where(
              'to_tsvector(\'english\', queries.user::text) @@ plainto_tsquery(\'english\', ?) OR to_tsvector(\'english\', queries.query) @@ plainto_tsquery(\'english\', ?)',
              search, search
            )
          end
          # figure out ordering
          columns = [ 'record_time', 'user', 'xid', 'query' ]
          order_str  = 'queries.'
          order_str += columns[order]
          order_str += ' asc' if orderdir == 'asc'
          order_str += ' desc' if orderdir == 'desc'
          q_query = q_query.order(order_str)
          # get data
          total_count = Models::Query.count
          filtered_count = q_query.count
          if length > 0
            queries = q_query.limit(length).offset(start).map do |q|
              tmp = q.attributes.reject { |k, v| k == 'created_at' || k == 'updated_at' }
              tmp['record_time'] = tmp['record_time']
              tmp['query'] = CodeRay.scan(Models::Query.query_for_display(tmp['query']), :sql).div()
              tmp
            end
          else
            queries = []
          end
          
          queries = {
            recordsTotal: total_count,
            recordsFiltered: filtered_count,
            data: queries
          }
          return queries
        end
      end
    end
  end
end

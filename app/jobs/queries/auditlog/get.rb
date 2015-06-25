module Jobs
  module Queries
    module AuditLog
      #
      # TODO can we not make that a background job and still hide all of the complexity in a good place?
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
          search_vec  = '' # non-quoted parts
          search_like = '' #     quoted parts
          unless search.blank?
            inquotes = false
            search.each_char do |c|
              if c == '"' && !inquotes
                inquotes = true
              elsif c == '"' && inquotes
                inquotes = false
              elsif inquotes
                search_like += c
              else
                search_vec  += c
              end
            end

            unless search_vec.blank?
              q_query = q_query.where(
                'to_tsvector(\'english\', queries.user::text) @@ plainto_tsquery(\'english\', ?) OR to_tsvector(\'english\', left(queries.query, 16384)) @@ plainto_tsquery(\'english\', ?)',
                search_vec, search_vec
              )
            end
            unless search_like.blank?
              q_query = q_query.where(
                'queries.query ilike ?', "%#{search_like}%"
              )
            end
          end
          # figure out ordering
          columns = [ 'record_time', 'user', 'xid', 'query' ]
          if order > -1
            order_str  = 'queries.'
            order_str += columns[order]
            order_str += ' asc' if orderdir == 'asc'
            order_str += ' desc' if orderdir == 'desc'
            q_query = q_query.order(order_str)
          elsif !search_vec.blank?
            q_query = q_query.order(
              "ts_rank_cd(to_tsvector(\'english\', left(queries.query, 16384)), plainto_tsquery(\'english\', '#{Desmond::PGUtil.escape_string(search_vec)}')) desc")
          end
          q_query = q_query.order('record_time desc')
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

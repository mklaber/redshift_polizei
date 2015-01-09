module Reports
  #
  # Report retrieving queries which are or were
  # running on the cluster
  #
  class Query < Base

    #
    # updates audit log of past queries
    #
    def run
      Tasks::AuditLog.update_from_s3
    end

    #
    # retrieves currently still executing queries
    #
    def running_queries
      sql = self.class.sanitize_sql(<<-SQL
        select
          'STV_INFLIGHT' as "source",
          queries.userid as user_id,
          users.usename as username,
          'In Flight' as status,
          starttime as start_time,
          null as end_time,
          null "sequence",
          xid,
          pid,
          '' as type,
          "text" as query
        from stv_inflight as queries
        inner join pg_user as users on queries.userid = users.usesysid
        where label = 'default'
        and username <> 'rdsdb'
        and username <> '%s'
        and lower(query) <> 'show search_path'
        and lower(query) <> 'select 1'
        order by "source", start_time desc, sequence asc
      SQL
      )

      result = self.class.select_all(sql, [self.class.database_user] * 2)
      result.chunk {|r| "#{r['pid']}#{r['start_time']}" }.collect do |query_grouping, query_parts|
        {
          'source' => query_parts.first['source'],
          'user_id' => query_parts.first['user_id'].try(:to_i),
          'username' => query_parts.first['username'].try(:strip),
          'status' => query_parts.first['status'],
          'start_time' => DateTime.parse(query_parts.first['start_time']).to_time.to_i,
          'end_time' => (DateTime.parse(query_parts.first['end_time']).to_time.to_i unless query_parts.first['end_time'].nil?),
          'duration' => ( 
            (
              ((DateTime.parse(query_parts.first['end_time']) - DateTime.parse(query_parts.first['start_time'])) * 24 * 60 * 60).to_f.round(2)
            ) unless query_parts.first['end_time'].nil?),
          'xid' => query_parts.first['xid'].try(:to_i),
          'pid' => query_parts.first['pid'].try(:to_i),
          'type' => query_parts.first['type'],
          'query' => query_parts.collect{|qp| qp['query'].try(:strip)}.join("")
        }
      end
    end

    #
    # returns the requested queries which are not yet in the audit log
    #
    def new_queries(selects, start, length, order=0, orderdir='desc', search)
      newest_audit_query = Models::Query.order("record_time DESC").first
      new_queries_from = nil
      if not newest_audit_query.nil?
        new_queries_from = Time.at(newest_audit_query.record_time).strftime('%Y-%m-%d %H:%M:%S')
      end

      sql_count = <<-SQL
        select
          COUNT(*) as cnt
      SQL
      sql_select = <<-SQL
        select
          queries.userid as userid,
          users.usename as user,
          queries.starttime as start_time,
          queries.endtime as end_time,
          queries.pid,
          queries.xid,
          queries.text as query
      SQL
      sql_from = <<-SQL
        from SVL_STATEMENTTEXT as queries
        inner join pg_user as users on queries.userid = users.usesysid
        where queries.label = 'default'
        and queries.sequence = 0
        and users.usename <> 'rdsdb'
        and users.usename <> '%s'
        and lower(queries.text) <> 'show search_path'
        and lower(queries.text) <> 'select 1'
        and lower(queries.text) <> 'commit'
      SQL
      sql_from += " and TIMESTAMP_CMP(queries.starttime, '#{new_queries_from}') > 0" if not new_queries_from.nil?
      sql_filter  = ''
      sql_filter += " and users.usename LIKE '%%%s%%' OR queries.text LIKE '%%%s%%'" if not (search.nil? || search.empty?)
      columns = [ 'queries.starttime', 'users.usename', 'queries.xid', 'queries.text' ]
      sql_order  = ''
      sql_order += " order by #{columns[order]}"
      sql_order += " desc" if orderdir == 'desc'
      sql_order += " asc" if orderdir == 'asc'

      total_count = self.class.select_all(sql_count + sql_from)[0]['cnt'].to_i
      result = self.class.select_all(sql_select + sql_from + sql_filter + sql_order, self.class.database_user, search, search)
      if not selects
        result = result.select do |q|
          (Models::Query.query_type(q['query']) > 0)
        end
      else
        result = result.to_a
      end

      filtered_count = result.size
      result = result[start, length] || []
      queries = result.map do |q|
        [
          DateTime.parse(q['start_time']).strftime('%F at %T %:z'),
          "#{q['user']} <small class=\"secondary\">(#{q['userid']})<small>",
          q['xid'],
          CodeRay.scan(Models::Query.query_for_display(q['query']), :sql).div()
        ]
      end
      return total_count, filtered_count, queries
    end
  
    #
    # returns the requested queries from the audit log
    #
    def audit_queries(selects, start, length, order=0, orderdir='desc', search)
      # q_query is the filter query
      q_query = Models::Query
      q_query = q_query.where(query_type: 1) if not selects
      # filter by search query
      if not search.empty?
        q_query = q_query.where(
          'queries.user LIKE ? OR queries.query LIKE ?', "%#{search}%", "%#{search}%"
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
          [
            Time.at(q.record_time).strftime('%F at %T %:z'),
            "#{q.user} <small class=\"secondary\">(#{q.userid})<small>",
            q.xid,
            CodeRay.scan(Models::Query.query_for_display(q.query), :sql).div()
          ]
        end
      else
        queries = []
      end
      return total_count, filtered_count, queries
    end

  end
end

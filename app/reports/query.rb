module Reports
  class Query < Base
  
    def run
      sql = self.sanitize_sql(<<-SQL
        (select 'SVL_STATEMENTTEXT' as "source", queries.userid as user_id, users.usename as username, 'Done' as status,
         starttime as start_time, endtime as end_time, "sequence", pid, type, "text" as query
        from SVL_STATEMENTTEXT as queries
        inner join pg_user as users on queries.userid = users.usesysid
        where
          label = 'default' and username <> 'rdsdb' and username <> 'polizei_bot'
          and lower(query) <> 'show search_path' and lower(query) <> 'select 1'
        order by start_time desc
        limit 100)       
        
        union all
        
        (select 'STV_INFLIGHT' as "source", queries.userid as user_id, users.usename as username, 'In Flight' as status,
         starttime as start_time, null as end_time,
         null "sequence", pid, '' as type, "text" as query
        from stv_inflight as queries
        inner join pg_user as users on queries.userid = users.usesysid
        where
          label = 'default' and username <> 'rdsdb' and username <> 'polizei_bot'
          and lower(query) <> 'show search_path' and lower(query) <> 'select 1')

         order by "source", start_time desc, sequence asc
        
      SQL
      )

      result = cache(sql, expires: 30) do
        self.redshift_select_all(sql)
      end
      result.chunk {|r| "#{r['pid']}#{r['start_time']}" }.collect do |query_grouping, query_parts|
        {
          'source' => query_parts.first['source'],
          'user_id' => query_parts.first['user_id'].try(:to_i),
          'username' => query_parts.first['username'].try(:strip),
          'status' => query_parts.first['status'],
          'start_time' => DateTime.parse(query_parts.first['start_time']),
          'end_time' => (DateTime.parse(query_parts.first['end_time']) unless query_parts.first['end_time'].nil?),
          'duration' => ( 
            (
              ((DateTime.parse(query_parts.first['end_time']) - DateTime.parse(query_parts.first['start_time'])) * 24 * 60 * 60).to_f.round(2)
            ) unless query_parts.first['end_time'].nil?),
          'pid' => query_parts.first['pid'].try(:to_i),
          'type' => query_parts.first['type'],
          'query' => query_parts.collect{|qp| qp['query'].try(:strip)}.join("")
        }
      end
    end
  
  end
end

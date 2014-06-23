module Reports
  class Query < Base
  
    attr_reader :options
  
    def initialize(unsanitized_options = {})
      # Ensure options are valid
      # this includes dealing with start_date, end_date
      @options = self.class.filter(unsanitized_options)
    end 
  
    def recents
      sql = <<-SQL
        --select queries.userid as user_id, users.usename as username, starttime as start_time, endtime as end_time,
        --sequence, type, (endtime - starttime) as duration, pid, "text" as query
        --from SVL_STATEMENTTEXT as queries
        --inner join pg_user as users on queries.userid = users.usesysid
      
        select userid as user_id, user_name as username, status, starttime as start_time, duration, pid, query
        from stv_recents
        where username <> 'rdsdb' and username <> 'polizei_bot'
          and query <> 'show search_path' and query <> 'SELECT 1'
        order by status <> 'Running', starttime desc ;
      SQL
      @result = self.class.connection.select_all(self.class.sanitize([sql, @options]))
    end
    
    def inflight
      sql = <<-SQL
        select userid as user_id, usename as username, 'In Flight'::varchar as status, starttime as start_time,
          datediff('seconds', convert_timezone('EDT',starttime), getdate()) as duration, pid, "text" as query
        from SVV_QUERY_INFLIGHT as inflight_queries
        inner join pg_catalog.pg_user as users on users.usesysid = inflight_queries.userid
        where username <> 'rdsdb' and username <> 'polizei_bot'
          and query <> 'show search_path' and query <> 'SELECT 1'
        order by starttime desc ;
      SQL
      @result = self.class.connection.select_all(self.class.sanitize([sql, @options]))
    end
  
  end
end

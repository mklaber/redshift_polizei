require './app/main'
require_relative 'base'

module Reports
  class AuditLog < Base
    def run(ua_log)
      prev_q = nil

      File.open(ua_log).each.each_with_index do |line, i|
        lineno = i + 1
        q = nil
        if line.match("'[0-9]{4}\-[0-9]{2}\-[0-9]{2}T").nil?
          # part of previous query => append to query
          raise "Corrupt file on line #{lineno}" if prev_q.nil?
          q = prev_q
          q.query += line
        else
          metadata_end = line.index(']\'')
          raise "Unsupported line format on line #{lineno}" if metadata_end.nil?
          metadata = line[0, metadata_end]
          metadata_parts = metadata.split(' ')
          raise "Unsupported metadata format on line #{lineno}" if metadata_parts.length != 8

          record_time = Time.iso8601(metadata_parts[0][1..-1])
          db     = metadata_parts[3].split('=')[-1]
          user   = metadata_parts[4].split('=')[-1]
          pid    = metadata_parts[5].split('=')[-1].to_i
          userid = metadata_parts[6].split('=')[-1].to_i
          xid    = metadata_parts[7].split('=')[-1].to_i
          query  = line[(metadata_end + 8)..-1]

          q = Models::Query.new
          q.assign_attributes(
            record_time: record_time,
            db: db,
            user: user,
            pid: pid,
            userid: userid,
            xid: xid,
            query: query.strip,
            logfile: ua_log
          )
        end

        prev_q = q
        begin
          q.save
        rescue
          p "Database error on line #{lineno}"
          raise
        end
      end
    end

    def audit_queries
      # from local datbase, no caching necessary
      Models::Query.order(:record_time).all.map { |q| q.attributes }
    end

    def running_queries
      # currently running queries, caching does not make sense
      sql = <<-SQL
        select
          queries.userid as user_id,
          users.usename as username,
          queries.starttime as start_time,
          queries.pid as pid,
          queries.xid as xid,
          queries.text as query
        from stv_inflight as queries
        inner join pg_user as users on queries.userid = users.usesysid
        where users.usename <> 'rdsdb'
          and users.usename <> '%s'
          and lower(queries.text) <> 'show search_path'
          and lower(queries.text) <> 'select 1'
      SQL
      self.redshift_select_all(sql, self.class.redshift_user).map do |query|
        {
          'record_time' => DateTime.parse(query['start_time']).utc,
          'user' => query['username'].strip,
          'pid' => query['pid'].to_i,
          'userid' => query['userid'].to_i,
          'xid' => query['xid'].to_i,
          'query' => query['query'].strip
        }
      end
    end
  end
end

if __FILE__ == $0
  abort "Usage:\n\tauditlog.rb user-activity-log\n" if ARGV.empty?
  Reports::AuditLog.new.run(ARGV[0])
end

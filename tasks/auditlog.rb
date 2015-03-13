require './app/main'

module Tasks
  #
  # Task retrieving queries from audit logs
  # may not have the newest queries, since this is
  # periodically built from the RedShift Audit Logs
  #
  class AuditLog
    def self.logger
      if @logger.nil?
        @logger = PolizeiLogger.logger('auditlog')
      end
      @logger
    end

    #
    # retrieves unprocessed audit logs from S3 and calls
    # `run` on them to parse them into the database.
    #
    # also runs `enforce_retention_period`
    #
    def self.update_from_s3
      self.logger.info "Updating Audit Log from S3 ..."
      auditlog = self.new
      auditlog.enforce_retention_period
      auditlogconfig = Models::AuditLogConfig.get
      last_update = DateTime.strptime(auditlogconfig.last_update.to_s, '%s').utc

      s3 = AWS::S3.new
      bucket = s3.buckets[GlobalConfig.aws('redshift_audit_log_bucket')]
      bucket.objects.each do |obj|
        begin
          is_user_activity_log = (not obj.key.index('useractivitylog').nil?)
          if is_user_activity_log && obj.last_modified > last_update
            # we are going to parse the file while downloading making this a little more complicated
            reader, writer = IO.pipe
            # "download" thread, can't do without it
            thread = Thread.new do
              begin
                obj.read do |chunk|
                  writer.write chunk
                end
              ensure
                writer.close
              end
            end
            # parse it after gzip decompression
            auditlog.run(Zlib::GzipReader.new(reader), obj.key)
          end
        rescue
          self.logger.error "Error parsing s3 object #{obj.key}"
          raise
        end
      end
      self.logger.info "... done updating Audit Log from S3 ..."
    rescue
      raise
    else
      # if no exception was thrown, update was successful
      auditlogconfig.last_update = Time.now.to_i
      auditlogconfig.save
    ensure
      # we need to VACUUM regularly, so that postgres uses the primary key index for count queries
      ActiveRecord::Base.connection.execute "VACUUM queries"
    end

    #
    # reclassifies queries to be run when the classification logic changed
    #
    def self.reclassify_queries
      Models::Query.all.each do |q|
        q.query_type = Models::Query.query_type(q.query)
        q.save
      end
    end

    #
    # removes old audit log queries from the database.
    # the cutoff date is retrieved thorugh Models::AuditLogConfig.
    #
    def enforce_retention_period
      # data retention, delete all old audit queries
      timestamp_now = Time.now.to_i
      retention_time = Models::AuditLogConfig.get.retention_period
      Models::Query.where('record_time < ?', timestamp_now - retention_time).destroy_all
    end

    #
    # parses audit log passed in with `ua_log` with
    # the given file name `logfile` and puts the contents
    # into the Models::Query table.
    #
    # `ua_log` has to respond to method `each_line` to
    # iterate over the file line-by-line.
    #
    # also runs `enforce_retention_period`
    #
    def run(ua_log, logfile)
      self.enforce_retention_period

      # read user activity log
      lineno = 0
      prev_q = nil
      ua_log.each_line do |line|
        lineno += 1
        q = nil
        if line.match("'[0-9]{4}\-[0-9]{2}\-[0-9]{2}T").nil?
          # part of previous query => append to query
          raise "Corrupt file on line #{lineno}" if prev_q.nil?
          q = prev_q
          q.query += line
          q.query_type = Models::Query.query_type(q.query)
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


          # save query
          q = Models::Query.new
          q.assign_attributes(
            record_time: record_time,
            db: db,
            user: user,
            pid: pid,
            userid: userid,
            xid: xid,
            query_type: Models::Query.query_type(query),
            query: query.strip,
            logfile: logfile
          )
        end

        prev_q = q
        begin
          q.save
        rescue
          self.logger.error "Database error on line #{lineno}"
          raise
        end
      end
    end
  end
end

#
# default action when executing file directly
#
if __FILE__ == $0
  begin
    if ARGV.empty?
      Tasks::AuditLog.update_from_s3
    else
      auditlog = Reports::AuditLog.new
      ARGV.each { |file| auditlog.run(File.read(file), file) }
    end
  rescue Interrupt
    # discard StackTrace if ctrl + c was pressed
    puts "Ctrl + C => exiting ..."
    exit
  end
end

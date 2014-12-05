require './app/main'
require_relative 'base'

module Reports
  #
  # Report retrieving queries for audit logs
  # may not have the newest queries, since this is
  # periodically built from the RedShift Audit Logs
  #
  class AuditLog < Base
    def self.update_from_s3
      logger = PolizeiLogger.logger
      auditlog = self.new
      auditlog.enforce_retention_period
      auditlogconfig = Models::AuditLogConfig.get
      last_update = DateTime.strptime(auditlogconfig.last_update.to_s,'%s').utc

      s3 = AWSConfig.s3_sdk
      bucket = s3.buckets['amg-redshift-logging'] # TODO configuration option
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
          logger.error "Error parsing s3 object #{obj.key}"
          raise
        end
      end
    rescue
      raise
    else
      # if no exception was thrown, update was successful
      auditlogconfig.last_update = Time.now.to_i
      auditlogconfig.save
    end

    def enforce_retention_period
      # data retention, delete all old audit queries
      timestamp_now = Time.now.to_i
      retention_time = Models::AuditLogConfig.get.retention_period
      Models::Query.where('record_time < ?', timestamp_now - retention_time).destroy_all
    end

    def run(ua_log, logfile)
      self.enforce_retention_period
      logger = PolizeiLogger.logger

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
          q.query_type = query_type(q.query)
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
            query_type: query_type(query),
            query: query.strip,
            logfile: logfile
          )
        end

        prev_q = q
        begin
          q.save
        rescue
          logger.error "Database error on line #{lineno}"
          raise
        end
      end
    end

    def audit_queries(with_selects)
      # from local database, no caching necessary
      Models::Query.order(record_time: :desc).all.select do |q|
        attrs = q.attributes
        qstr = attrs['query'].downcase.strip
        is_select   = (qstr.start_with?('select'))
        is_select ||= (qstr.start_with?('show'))
        is_select ||= (qstr.start_with?('set client_encoding'))
        is_select ||= (qstr.start_with?('set statement_timeout'))
        is_select ||= (qstr.start_with?('set query_group'))
        is_select ||= (qstr.start_with?('set search_path'))
        !is_select || (with_selects && is_select)
      end.map do |q|
        attrs = q.attributes
        attrs['record_time'] = Time.at(attrs['record_time'])
        attrs
      end
    end

    private
      def strip_comments(q)
        q = q.gsub(/--(.*)/, '') # singe line -- comments
        q = q.gsub(/(\/\*).+(\*\/)/m, '') # multi-line /**/ comments
      end

      def query_type(query)
        # determine what kind kind of query
        qstr = strip_comments(query.downcase).strip
        is_select   = (qstr.start_with?('select'))
        is_select ||= (qstr.start_with?('show'))
        is_select ||= (qstr.start_with?('set client_encoding'))
        is_select ||= (qstr.start_with?('set statement_timeout'))
        is_select ||= (qstr.start_with?('set query_group'))
        is_select ||= (qstr.start_with?('set search_path'))
        return ((is_select) ? 0 : 1)
      end
  end
end

if __FILE__ == $0
  begin
    if ARGV.empty?
      Reports::AuditLog.update_from_s3
    else
      auditlog = Reports::AuditLog.new
      ARGV.each { |file| auditlog.run(File.read(file), file) }
    end
  rescue Interrupt
    # discard StackTrace if ctrl + c was pressed
    logger.info "Ctrl + C => exiting ..."
    exit
  end
end

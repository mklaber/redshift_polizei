module Jobs
  module Queries
    module AuditLog
      #
      # Job importing new queries into local audit log
      #
      class Import < Desmond::BaseJobNoJobId
        extend Jobs::BaseReportNoJobId

        def execute(job_id, user_id, options={})
          Jobs::Queries::AuditLog::EnforceRetention.run(user_id)
          auditlogconfig = Models::AuditLogConfig.get
          last_update = DateTime.strptime(auditlogconfig.last_update.to_s, '%s').utc

          iterate_log_streams(last_update, options[:file], options[:just_one]) do |reader, logfile_name|
            import(reader, logfile_name)
          end
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

        private

        def iterate_log_streams(last_update, file, just_one, &block)
          unless file.nil?
            block.call(File.open(file, 'r'), file)
          else
            bucket = AWS::S3.new.buckets[GlobalConfig.aws('redshift_audit_log_bucket')]
            # start from the newest and work our way back
            bucket.objects.sort_by { |obj| obj.last_modified }.reverse.each do |obj|
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
                  block.call(Zlib::GzipReader.new(reader), obj.key)
                  return if just_one
                end
              end
            end
          end
        end

        def import(reader, logfile_name)
          Que.log level: :info, message: "Importing #{logfile_name}"
          # read user activity log
          lineno = 0
          prev_q = nil
          reader.each_line do |line|
            lineno += 1
            q = nil
            if line.match("'[0-9]{4}\-[0-9]{2}\-[0-9]{2}T").nil?
              # part of previous query => append to query
              raise "Corrupt file on line #{lineno} in file #{logfile_name}" if prev_q.nil?
              q = prev_q
              q.query += line
            else
              metadata_end = line.index(']\'')
              raise "Unsupported line format on line #{lineno} in file #{logfile_name}" if metadata_end.nil?
              metadata = line[0, metadata_end]
              metadata_parts = metadata.split(' ')
              raise "Unsupported metadata format on line #{lineno} in file #{logfile_name}" if metadata_parts.length != 8

              record_time = Time.iso8601(metadata_parts[0][1..-1])
              db     = metadata_parts[3].split('=')[-1]
              user   = metadata_parts[4].split('=')[-1]
              pid    = metadata_parts[5].split('=')[-1].to_i
              userid = metadata_parts[6].split('=')[-1].to_i
              xid    = metadata_parts[7].split('=')[-1].to_i
              query  = line[(metadata_end + 8)..-1]


              # save query
              unless prev_q.nil?
                prev_q.query.strip!
                prev_q.save
              end
              q = Models::Query.new
              q.assign_attributes(
                record_time: record_time,
                db: db,
                user: user,
                pid: pid,
                userid: userid,
                xid: xid,
                query_type: Models::Query.query_type(query),
                query: query,
                logfile: logfile_name
              )
            end

            prev_q = q
            begin
              q.save
            rescue
              Que.log level: :error, msg: "Database error on line #{lineno} in file #{logfile_name}"
              raise
            end
          end
          unless prev_q.nil?
            prev_q.query.strip!
            prev_q.save
          end
        end
      end
    end
  end
end

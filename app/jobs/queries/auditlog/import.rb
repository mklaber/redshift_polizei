require 'activerecord-import/base'
ActiveRecord::Import.require_adapter('postgresql')
MAX_IMPORT_SIZE = 300 # due to memory constraints we shouldn't import too many queries at once

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
            import(reader, logfile_name, options)
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
            bucket  = AWS::S3.new.buckets[GlobalConfig.polizei('aws_redshift_audit_log_bucket')]
            objects = bucket.objects
            if just_one && !just_one.to_b # just_one is set, but not a boolean, so we'll try to filter by filename
              objects = objects.select { |o| File.basename(o.key) == just_one }
            end
            # start from the newest and work our way back
            tmp = objects.sort_by { |obj| obj.last_modified }.reverse
            #tmp = bucket.objects
            tmp.each do |obj|
              begin
                filename       = obj.key.split('/')[-1].split('.')[0] # gets rid of the path before the actual filename
                filename_parts = filename.split('_') # the filename contains several pieces of info
                cluster_name   = filename_parts[3]
                logtype        = filename_parts[4]
                logtimestamp   = filename_parts[5]

                is_our_cluster       = (cluster_name == GlobalConfig.polizei('aws_cluster_identifier'))
                is_user_activity_log = (logtype == 'useractivitylog')
                #Que.log level: :debug, message: "log file from '#{cluster_name}' of type '#{logtype}' timed at #{logtimestamp}: #{is_our_cluster}, #{is_user_activity_log}, #{obj.last_modified > last_update}"
                if is_our_cluster && is_user_activity_log && obj.last_modified > last_update
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

        def import(reader, logfile_name, options={})
          Que.log level: :info, message: "Importing #{logfile_name}"
          max_import_size = options[:max_import_size] || MAX_IMPORT_SIZE
          # read user activity log
          lineno = 0
          columns = [ :record_time, :db, :user, :pid, :userid, :xid, :query_type, :query, :logfile ]
          import_options = { validate: false }
          queries = []
          reader.each_line do |line|
            lineno += 1
            if line.match("'[0-9]{4}\-[0-9]{2}\-[0-9]{2}T").nil?
              next if lineno == 1 # the first line sometimes contains a single query, which makes the file corrupt
              # part of previous query => append to query
              raise "Corrupt file on line #{lineno} in file #{logfile_name}" if queries.empty?
              queries.last[7] += line
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


              # remember queries to import them all at once later
              queries.last[7].strip! unless queries.empty?
              if queries.size >= max_import_size
                Models::Query.import columns, queries, import_options
                queries.clear # we do not want to import the same ones again
              end
              queries << [
                record_time,
                db,
                user,
                pid,
                userid,
                xid,
                Models::Query.query_type(query),
                query,
                logfile_name
              ]
            end
          end

          queries.last[7].strip! unless queries.empty?
          # import all queries at once
          Models::Query.import columns, queries, import_options
        end
      end
    end
  end
end

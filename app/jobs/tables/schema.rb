require_relative '../../main'

module Jobs
  ##
  # exports the table structure of a set of tables
  # in the background.
  # does NOT support compound pk, fk or unqiue constraints!
  #
  class TableStructureExportJob < Desmond::BaseJob
    def self.logger
      @logger ||= PolizeiLogger.logger('tablestructure')
    end
    def logger
      self.class.logger
    end

    ##
    # error hook
    #
    def error(job_run, job_id, user_id, options={})
      subject = "ERROR: Your RedShift table schemas export failed"
      body = "Sorry, your table schemas export failed.
This can happen if tables get deleted during the export, so please try once more and then let engineering know."
      
      mail_options = {
        cc: GlobalConfig.polizei('job_failure_cc'),
        bcc: GlobalConfig.polizei('job_failure_bcc')
      }.merge(options.fetch(:mail, {}))
      mail(options[:email], subject, body, mail_options)
    end

    ##
    # success hook
    #
    def success(job_run, job_id, user_id, options={})
      dl_url = AWS::S3.new.buckets[job_run.result['bucket']].objects[job_run.result['key']].url_for(
        :read,
        expires: (14 * 86400),
        response_content_type: "application/octet-stream"
      ).to_s
      view_url = AWS::S3.new.buckets[job_run.result['bucket']].objects[job_run.result['key']].url_for(
        :read,
        expires: (14 * 86400)
      ).to_s
      subject = "Your RedShift table schemas export succeeded"
      body = "Congrats! Your table schemas export is located
as a direct download here: #{dl_url}
You can view it in your browser by using this link: #{view_url}"

      mail(options[:email], subject, body, options.fetch(:mail, {}))
    end

    ##
    # actual job
    #
    def execute(job_id, user_id, options={})
      time = Time.now.utc.strftime('%Y_%m_%dT%H_%M_%S_%LZ')
      s3_bucket = GlobalConfig.aws('export_bucket')
      s3_key = "table_structure_export_#{user_id}_#{time}.sql"

      table = {}
      schema_name = options[:schema_name]
      table_name = options[:table_name]
      table = { schema_name: schema_name, table_name: table_name } unless schema_name.nil? && table_name.nil?

      begin
        s3writer = Desmond::Streams::S3::S3Writer.new(s3_bucket, s3_key, options.fetch(:s3, {}))

        # occasionally one of these queries can fail with the error:
        # relation with OID XXXX does not exist
        # see: http://www.postgresql.org/message-id/29508.1187413841@sss.pgh.pa.us
        columns, constraints, diststyle, sort_dist_keys = nil
        tables = []
        RSPool.with do |connection|
          columns        = TableUtils.get_columns(connection, table)
          constraints    = TableUtils.get_table_constraints(connection, table)
          diststyle      = TableUtils.get_dist_styles(connection, table)
          sort_dist_keys = TableUtils.get_sort_and_dist_keys(connection, table)
          columns.each do |full_table_name, col_defs|
            tables << {
              schema_name: col_defs[0]['schema_name'],
              table_name: col_defs[0]['table_name'],
              full_table_name: full_table_name
            }
          end
        end

        s3writer.write("---------- #{tables.size} tables exported ----------\n") unless options[:nospacer]
        tables.map do |tbl|
          table_sql = build_sql(
            tbl[:schema_name],
            tbl[:table_name],
            columns[tbl[:full_table_name]],
            constraints[tbl[:full_table_name]],
            diststyle[tbl[:full_table_name]],
            sort_dist_keys[tbl[:full_table_name]]
          )

          s3writer.write("\n---------- #{tbl[:schema_name]}.#{tbl[:table_name]} ----------\n") unless options[:nospacer]
          s3writer.write(table_sql)
          s3writer.write("\n\n") unless options[:nospacer]
        end
        { bucket: s3_bucket, key: s3_key }
      ensure
        s3writer.close unless s3writer.nil?
      end
    end

    private

    ##
    # send mail
    #
    def mail(to, subject, body, options={})
      pony_options = { to: to, subject: subject, body: body }.merge(options)
      Pony.mail(pony_options) unless options[:nomailer]
    end

    ##
    # rebuilds and returns the SQL to recreate the given table
    #
    def build_sql(schema_name, table_name, columns, constraints, diststyle, sort_dist_keys)
      constraints ||= []
      sort_dist_keys ||= {}
      diststyle = diststyle['dist_style']
      sortkeys = sort_dist_keys['sort_keys'] || []
      distkey = sort_dist_keys['dist_key'] || nil

      schema_name_sql = self.class.escape_rs_identifier(schema_name)
      table_name_sql  = self.class.escape_rs_identifier(table_name)
      distkey_sql     = self.class.escape_rs_identifier(distkey) unless distkey.nil?
      sortkeys_sql    = sortkeys.map { |sk| self.class.escape_rs_identifier(sk) }.join(', ') unless sortkeys.nil?
      structure_sql   = "CREATE TABLE #{schema_name_sql}.#{table_name_sql}(\n"
      structure_sql  += columns.map do |column|
        column_name_sql  = self.class.escape_rs_identifier(column['name'])
        column_type_sql  = column['type']
        column_type_sql += "(#{column['varchar_len']})" unless column['varchar_len'].nil?
        column_type_sql += "(#{column['numeric_precision']}, #{column['numeric_scale']})" if column['type'].downcase == 'decimal' || column['type'].downcase == 'numeric'
        column_encoding_sql = (column['encoding'].downcase == 'none') ? 'raw' : column['encoding']
        "\t#{column_name_sql} #{column_type_sql} #{(column['is_nullable'] == 'YES') ? 'NULL' : 'NOT NULL'}#{(column['identity'].nil?) ? '' : ' IDENTITY(' + column['identity'] + ')'}#{(column['default'].nil?) ? '' : ' DEFAULT ' + column['default']} ENCODE #{column_encoding_sql}"
      end.join(",\n")
      structure_sql  += ",\n" unless constraints.empty?
      structure_sql  += constraints.map do |constraint|
        column_name_sql  = self.class.escape_rs_identifier(constraint['contraint_columnname'])
        if constraint['constraint_type'] == 'u'
          "\tUNIQUE (#{column_name_sql})"
        elsif constraint['constraint_type'] == 'p'
          "\tPRIMARY KEY (#{column_name_sql})"
        elsif constraint['constraint_type'] == 'f'
          ref_schema_name_sql = self.class.escape_rs_identifier(constraint['ref_namespace'])
          ref_table_name_sql  = self.class.escape_rs_identifier(constraint['ref_tablename'])
          ref_column_name_sql  = self.class.escape_rs_identifier(constraint['ref_columnname'])
          "\tFOREIGN KEY (#{column_name_sql}) REFERENCES #{ref_schema_name_sql}.#{ref_table_name_sql} (#{ref_column_name_sql})"
        else
          fail "Unsupported constraint_type '#{constraint['constraint_type']}'"
        end
      end.join(",\n")
      structure_sql  += "\n)\n"
      structure_sql  += "DISTSTYLE #{diststyle}\n"
      structure_sql  += "DISTKEY (#{distkey_sql})\n" unless distkey.nil?
      structure_sql  += "SORTKEY (#{sortkeys_sql})\n" unless sortkeys.empty?
      structure_sql  += ';'
      structure_sql
    rescue => e
      Que.log level: :error, message: "table #{schema_name}.#{table_name} caused trouble"
      raise e
    end

    ##
    # escapes a RedShift identifier
    #
    def self.escape_rs_identifier(name)
      if name.size > 63
        # redshift allows this, pg doesn't
        # quote and escape all quotes within
        "\"#{name.gsub('"'){'\"'}}\""
      else
        PG::Connection.quote_ident(name)
      end
    end
  end
end

if __FILE__ == $0

  puts Jobs::TableStructureExportJob.run(1, 1, schema_name: ARGV[0], table_name: ARGV[1], s3: {
    access_key_id: GlobalConfig.aws('access_key_id'),
    secret_access_key: GlobalConfig.aws('secret_access_key')
  })
end

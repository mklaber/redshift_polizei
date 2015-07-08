require_relative '../../main'
require 'set'

module Jobs
  # TODO use desmond version, once/if available?, keep email hooks

  ##
  # exports the table structure of a set of tables
  # in the background.
  # does NOT support compound pk, fk or unqiue constraints!
  #
  class TableStructureExportJob < Desmond::BaseJob # TODO doesn't need job id

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
    # the following +options+ are additionally supported:
    # - db
    #   - export_single_table: if true, will not include the dependencies for the specified table
    #   - no_column_encoding: if true, will not include the column encodings
    #   - diststyle_override: override for distribution styles {'EVEN' | 'KEY' | 'ALL'}
    #   - distkey_override: override for distribution keys. only valid for KEY diststyle
    #   - sortstyle_override: override for sort styles { '' | 'COMPOUND' | 'INTERLEAVED' }
    #   - sortkeys_override: override for sort keys. only valid is there's a sortstyle
    #
    def execute(job_id, user_id, options={})
      time = Time.now.utc.strftime('%Y_%m_%dT%H_%M_%S_%LZ')
      s3_bucket = options[:s3_bucket] || GlobalConfig.polizei('aws_export_bucket')
      s3_key = options[:s3_key] || "table_structure_export_#{user_id}_#{time}.sql"

      table = {}
      schema_name = options[:schema_name]
      table_name = options[:table_name]
      table = { schema_name: schema_name, table_name: table_name } unless schema_name.nil? && table_name.nil?

      # keeping track of tables so they can be exported in the right order
      # regarding their foreign key dependencies
      @exported_tables = Set.new
      @waiting_tables = {}

      begin
        s3_writer = Desmond::Streams::S3::S3Writer.new(s3_bucket, s3_key, options.fetch(:s3, {}))

        # get data for tables
        tables = []
        RSPool.with do |connection|
          tables = get_tables_data_with_dependencies(connection, table)
        end

        s3_writer.write("---------- #{tables.size} tables exported ----------\n") unless options[:nospacer]
        tables.each do |tbl|
          # build sql
          table_sql = build_sql(
            tbl[:schema_name],
            tbl[:table_name],
            tbl[:columns],
            tbl[:constraints],
            tbl[:sort_dist_styles],
            tbl[:sort_dist_keys]
          )

          # write to S3
          if @exported_tables.superset?(tbl[:dependencies])
            # write SQL to file if all dependencies have been written
           write_to_s3(s3_writer, tbl[:schema_name], tbl[:table_name], table_sql, options)
          else
            # not all dependencies have been written, wait until they have been
            @waiting_tables[tbl[:full_table_name]] = {
              schema_name: tbl[:schema_name],
              table_name: tbl[:table_name],
              sql: table_sql,
              dependens_on: tbl[:dependencies]
            }
          end
        end

        # make sure all tables have been written
        unless @waiting_tables.empty?
          fail "Cyclic dependency? Could not clear all dependencies: #{@waiting_tables.keys}"
        end
        # everything went well
        { bucket: s3_bucket, key: s3_key }
      ensure
        s3_writer.close unless s3_writer.nil?
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
    # returns all describing data about a table in a hash structure
    #
    def get_tables_data_with_dependencies(connection, table)
      # occasionally one of these queries can fail with the error:
      # relation with OID XXXX does not exist
      # see: http://www.postgresql.org/message-id/29508.1187413841@sss.pgh.pa.us
      columns          = TableUtils.get_columns(connection, table)
      constraints      = TableUtils.get_table_constraints(connection, table)
      sort_dist_styles = TableUtils.get_sort_and_dist_styles(connection, table)
      sort_dist_keys   = TableUtils.get_sort_and_dist_keys(connection, table)

      table_names    = Set.new(columns.keys)
      dependencies   = calculate_tables_dependencies(constraints)

      tables = []
      columns.each do |full_table_name, col_defs|
        table_dependencies = dependencies[full_table_name] || Set.new

        # make sure we have the data for all dependencies
        unless table_names.superset?(table_dependencies) || options[:export_single_table]
          table_dependencies.each do |table_dependency|
            schema_name, table_name = deconstruct_full_table_name(table_dependency)
            tables += get_tables_data_with_dependencies(connection,
              schema_name: schema_name, table_name: table_name)
          end
        end

        # merge data and save in array of all tables
        tables << {
          schema_name: col_defs[0]['schema_name'],
          table_name: col_defs[0]['table_name'],
          full_table_name: full_table_name,
          dependencies: table_dependencies,
          columns: columns[full_table_name],
          constraints: constraints[full_table_name],
          sort_dist_styles: sort_dist_styles[full_table_name],
          sort_dist_keys: sort_dist_keys[full_table_name]
        }
      end
      return tables
    end

    ##
    # returns the dependencies of tables given its constraints
    #
    def calculate_tables_dependencies(constraints)
      constraints.hmap do |full_table_name, tbl_constraints|
        foreign_keys = []
        unless tbl_constraints.nil? || tbl_constraints.empty?
          foreign_keys = tbl_constraints.select do |constraint|
            constraint['constraint_type'] == 'f'
          end
        end
        Set.new(foreign_keys.map do |fk|
          TableUtils.build_full_table_name(fk['ref_namespace'], fk['ref_tablename'])
        end)
      end
    end

    ##
    # returns schema_name and table_name out of a full table name
    #
    def deconstruct_full_table_name(full_table_name)
      fail 'Not a full table name!' if full_table_name.count('.') == 0
      fail 'Dots in schema or table name not supported!' if full_table_name.count('.') > 1
      parts = full_table_name.split('.')
      return parts[0], parts[1]
    end

    ##
    # rebuilds and returns the SQL to recreate the given table
    #
    def build_sql(schema_name, table_name, columns, constraints, sort_dist_styles, sort_dist_keys)
      constraints ||= []
      sort_dist_keys ||= {}
      sortstyle = sort_dist_styles['sort_style']
      diststyle = sort_dist_styles['dist_style']
      sortkeys  = sort_dist_keys['sort_keys'] || []
      distkey   = sort_dist_keys['dist_key'] || nil

      # override table schema if the options specify
      diststyle = self.options[:diststyle_override] if self.options.key?(:diststyle_override)
      distkey = self.options[:distkey_override] if self.options.key?(:distkey_override)
      sortstyle = self.options[:sortstyle_override] if self.options.key?(:sortstyle_override)
      sortkeys = self.options[:sortkeys_override] if self.options.key?(:sortkeys_override)

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

        column_sql  = "\t#{column_name_sql} #{column_type_sql}"
        column_sql += ' NULL'                                if column['is_nullable'] == 'YES'
        column_sql += ' NOT NULL'                            if column['is_nullable'] != 'YES'
        column_sql += " IDENTITY(#{column['identity']})" unless column['identity'].nil?
        column_sql += " DEFAULT #{column['default']}"    unless column['default'].nil?
        column_sql += " ENCODE #{column_encoding_sql}"   unless self.options[:no_column_encoding]
        column_sql
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
      structure_sql  += "DISTSTYLE #{Desmond::PGUtil.escape_string(diststyle)}\n" unless diststyle.nil? || diststyle.empty?
      structure_sql  += "DISTKEY (#{distkey_sql})\n" unless distkey.nil? || distkey.empty?
      structure_sql  += "#{Desmond::PGUtil.escape_string(sortstyle.upcase)} " unless sortstyle.nil? || sortstyle.empty?
      structure_sql  += "SORTKEY (#{sortkeys_sql})\n" unless sortkeys.nil? || sortkeys.empty?
      structure_sql  += ';'
      structure_sql
    rescue => e
      Que.log level: :error, message: "table #{schema_name}.#{table_name} caused trouble"
      raise e
    end

    ##
    # write +table_sql+ out to S3 and check if new dependencies have been fulfilled
    #
    def write_to_s3(s3_writer, schema_name, table_name, table_sql, options={})
      # write table out
      full_table_name = TableUtils.build_full_table_name(schema_name, table_name)
      s3_writer.write("\n---------- #{full_table_name} ----------\n") unless options[:nospacer]
      s3_writer.write(table_sql)
      s3_writer.write("\n\n") unless options[:nospacer]
      @exported_tables << TableUtils.build_full_table_name(schema_name, table_name)

      # check if any new dependencies were fulfilled
      dependencies_fulfilled = @waiting_tables.select do |full_table_name, tbl|
        @exported_tables.superset?(tbl[:dependens_on])
      end
      @waiting_tables = @waiting_tables.delete_if do |full_table_name, tbl|
        dependencies_fulfilled.has_key?(full_table_name)
      end
      # write newly fulfilled tables out recursivly
      dependencies_fulfilled.each do |full_table_name, tbl|
        write_to_s3(s3_writer, tbl[:schema_name], tbl[:table_name], tbl[:sql])
      end
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

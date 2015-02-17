require_relative '../main'

module Jobs
  ##
  # exports the table structure of a set of tables
  # in the background.
  # does NOT support compound pk, fk or unqiue constraints!
  #
  class TableStructureExportJob < Desmond::BaseJob
    ##
    # error hook
    #
    def error(job_run, job_id, user_id, options={})
      subject = "ERROR: Your RedShift table schemas export failed"
      body = "Sorry, your table schemas export failed.
This can happen if tables get deleted during the export, so please try once more and then let engineering know."
      
      mail_options = {
        cc: Sinatra::Configurations.polizei('job_failure_cc'),
        bcc: Sinatra::Configurations.polizei('job_failure_bcc')
      }.merge(options.fetch('mail', {}))
      mail(options['email'], subject, body, mail_options)
    end

    ##
    # success hook
    #
    def success(job_run, job_id, user_id, options={})
      dl_url = AWS::S3.new.buckets[job_run.details['bucket']].objects[job_run.details['key']].url_for(
        :read,
        expires: (14 * 86400),
        response_content_type: "application/octet-stream"
      ).to_s
      view_url = AWS::S3.new.buckets[job_run.details['bucket']].objects[job_run.details['key']].url_for(
        :read,
        expires: (14 * 86400)
      ).to_s
      subject = "Your RedShift table schemas export succeeded"
      body = "Congrats! Your table schemas export is located
as a direct download here: #{dl_url}
You can view it in your browser by using this link: #{view_url}"

      mail(options['email'], subject, body, options.fetch('mail', {}))
    end

    ##
    # actual job
    #
    def execute(job_id, user_id, options={})
      time = Time.now.utc.strftime('%Y_%m_%dT%H_%M_%S_%LZ')
      s3_bucket = Sinatra::Configurations.aws('export_bucket')
      s3_key = "table_structure_export_#{user_id}_#{time}.sql"

      schema_name = options[:schema_name]
      table_name = options[:table_name]

      begin
        s3writer = Desmond::Streams::S3::S3Writer.new(s3_bucket, s3_key, options.fetch(:s3, {}))

        # occasionally one of these queries can fail with the error:
        # relation with OID XXXX does not exist
        # see: http://www.postgresql.org/message-id/29508.1187413841@sss.pgh.pa.us
        columns        = get_columns(schema_name, table_name)
        constraints    = get_table_constraints_by_name(schema_name, table_name)
        diststyle      = get_dist_style_by_name(schema_name, table_name)
        sort_dist_keys = get_sort_and_dist_keys_by_name(schema_name, table_name)
        tables         = []
        columns.each do |full_table_name, col_defs|
          tables << {
            schema_name: col_defs[0]['schema_name'],
            table_name: col_defs[0]['table_name'],
            full_table_name: full_table_name
          }
        end

        s3writer.write("---------- #{tables.size} tables exported ----------\n")
        tables.map do |tbl|
          table_sql = build_sql(
            tbl[:schema_name],
            tbl[:table_name],
            columns[tbl[:full_table_name]],
            constraints[tbl[:full_table_name]],
            diststyle[tbl[:full_table_name]],
            sort_dist_keys[tbl[:full_table_name]]
          )

          s3writer.write("\n---------- #{tbl[:schema_name]}.#{tbl[:table_name]} ----------\n")
          s3writer.write(table_sql)
          s3writer.write("\n\n")
        end
        done(bucket: s3_bucket, key: s3_key)
      ensure
        s3writer.close unless s3writer.nil?
      end
    rescue => e
      self.logger.error "Error executing TableStructureExport job for #{user_id} with #{options}:"
      self.logger.exception e
      raise e
    end

    private

    ##
    # send mail
    #
    def mail(to, subject, body, options={})
      pony_options = { to: to, subject: subject, body: body }.merge(options)
      Pony.mail(pony_options)
    end

    ##
    # rebuilds and returns the SQL to recreate the given table
    #
    def build_sql(schema_name, table_name, columns, constraints, diststyle, sort_dist_keys)
      constraints ||= []
      sort_dist_keys ||= {}
      diststyle = diststyle['diststyle']
      sortkeys = sort_dist_keys['sortkeys'] || []
      distkey = sort_dist_keys['distkey'] || nil

      schema_name_sql = self.class.escape_rs_identifier(schema_name)
      table_name_sql  = self.class.escape_rs_identifier(table_name)
      distkey_sql     = self.class.escape_rs_identifier(sort_dist_keys['distkey']) unless distkey.nil?
      sortkeys_sql    = sortkeys.map { |sk| self.class.escape_rs_identifier(sk) }.join(', ') unless sortkeys.nil?
      structure_sql   = "CREATE TABLE #{schema_name_sql}.#{table_name_sql}(\n"
      structure_sql  += columns.map do |column|
        column_name_sql  = self.class.escape_rs_identifier(column['name'])
        column_type_sql  = column['type']
        column_type_sql += "(#{column['varchar_len']})" unless column['varchar_len'].nil?
        column_type_sql += "(#{column['numeric_precision']}, #{column['numeric_scale']})" if column['type'].downcase == 'decimal' || column['type'].downcase == 'numeric'
        column_encoding_sql = (column['encoding'].downcase == 'none') ? 'raw' : column['encoding']
        "\t#{column_name_sql} #{column_type_sql}#{(column['identity'].nil?) ? '' : ' IDENTITY(' + column['identity'] + ')'}#{(column['default'].nil?) ? '' : ' DEFAULT' + column['default']} #{(column['is_nullable'] == 'YES') ? 'NULL' : 'NOT NULL'} ENCODE #{column_encoding_sql}"
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
          "\tFOREIGN KEY (#{column_name_sql}) REFERENCES #{ref_schema_name_sql}.#{ref_table_name_sql}(#{ref_column_name_sql})"
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
    # returns the columns with all their properties in the defined order of
    # the given table.
    # to retrieve sort & dist keys use `get_sort_and_dist_keys_by_name`
    #
    def get_columns(schema_name, table_name)
      sql = <<-SQL
        select
          cols.table_schema AS schema_name,
          cols.table_name,
          cols.ordinal_position,
          cols.column_name as name,
          cols.data_type as type,
          cols.character_maximum_length as varchar_len,
          cols.numeric_precision,
          cols.numeric_scale,
          cols.is_nullable,
          cols.column_default as "default",
          format_encoding(a.attencodingtype::integer) as encoding,
          i.identity_vals as "identity"
        from information_schema.columns cols
        join pg_class c on c.relname = cols.table_name
        join pg_namespace n on n.oid = c.relnamespace and n.nspname = cols.table_schema
        join pg_attribute a on a.attnum > 0 and not a.attisdropped and c.oid = a.attrelid and cols.column_name = a.attname
        left join (select c.oid as table_id, a.attname as column_name, d.adsrc as identity_def, substr(d.adsrc, (len(d.adsrc) - charindex(',', reverse(d.adsrc))), (len(d.adsrc) - charindex('''', reverse(d.adsrc)) - (len(d.adsrc) - charindex(',', reverse(d.adsrc)))) + 1) as identity_vals
          from pg_class c, pg_attribute a, pg_attrdef d, pg_namespace n
          where c.oid = a.attrelid
          and c.relkind = 'r'
          and n.oid = c.relnamespace
          and a.attrelid = d.adrelid
          and a.attnum = d.adnum
          and d.adsrc like '%%identity%%') i on i.table_id = c.oid and i.column_name = cols.column_name
        where trim(n.nspname) not in ('pg_catalog', 'information_schema')
      SQL
      sql += "and trim(n.nspname) = '%s'" unless schema_name.nil?
      sql += "and trim(c.relname) = '%s'" unless table_name.nil?
      sql += "order by cols.ordinal_position;"
      self.class.select_all_grouped_by_table(sql, schema_name, table_name)
    end

    ##
    # retrieves the distribution style of the given table
    #
    def get_dist_style_by_name(schema_name, table_name)
      sql = <<-SQL
        select distinct
          trim(n.nspname) as schema_name,
          trim(c.relname) as table_name,
          decode(c.reldiststyle,0,'even',1,'key',8,'all') as diststyle
        from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
        where trim(n.nspname) not in ('pg_catalog', 'information_schema')
      SQL
      sql += "and trim(n.nspname) = '%s'" unless schema_name.nil?
      sql += "and trim(c.relname) = '%s'" unless table_name.nil?
      tmp_results = self.class.select_all_grouped_by_table(sql, schema_name, table_name)
      results = {}
      tmp_results.each { |full_table_name, value| results[full_table_name] = value[0] }
      results
    end

    ##
    # retrieves the sort keys and distribution key for the given table
    #
    def get_sort_and_dist_keys_by_name(schema_name, table_name)
      sql = <<-SQL
        select
          trim(n.nspname) as schema_name,
          trim(c.relname) as table_name,
          a.attname,
          a.attsortkeyord,
          a.attisdistkey
        from pg_class c
        join pg_attribute a on a.attrelid = c.oid
        join pg_namespace n on n.oid = c.relnamespace
        where (a.attsortkeyord > 0
        or a.attisdistkey is true)
        and trim(n.nspname) not in ('pg_catalog', 'information_schema')
      SQL
      sql += "and trim(n.nspname) = '%s'" unless schema_name.nil?
      sql += "and trim(c.relname) = '%s'" unless table_name.nil?
      sql += "order by a.attsortkeyord asc"

      tmp_results = self.class.select_all_grouped_by_table(sql, schema_name, table_name)
      results = {}
      tmp_results.each do |full_table_name, result|
        sortkeys = result.select { |r| (r['attsortkeyord'].to_i > 0) }.map do |r|
          r['attname']
        end
        distkey = nil
        tmp = result.select { |r| (r['attisdistkey'] == 't') }
        distkey = tmp[0]['attname'] if not tmp.empty?
        results[full_table_name] = { 'sortkeys' => sortkeys, 'distkey' => distkey }
      end
      return results
    end

    ##
    # retrieves the primary and foreign key as well as the unique constraints
    # for the given table.
    # does not support compound keys!
    #
    def get_table_constraints_by_name(schema_name, table_name)
      sql = <<-SQL
        select
          trim(n.nspname) as schema_name,
          trim(c.relname) as table_name,
          cs.contype as constraint_type,
          t1.attname as contraint_columnname,
          n2.nspname as ref_namespace,
          c2.relname as ref_tablename,
          t2.attname as ref_columnname
        from pg_constraint cs
        inner join pg_class c on cs.conrelid = c.oid
        inner join pg_namespace n on n.oid = c.relnamespace
        inner join pg_attribute t1 on t1.attrelid = cs.conrelid and t1.attnum = cs.conkey[1] and t1.attnum > 0 and not t1.attisdropped
        left join pg_class c2 on cs.confrelid = c2.oid
        left join pg_namespace n2 on n2.oid = c2.relnamespace
        left join pg_attribute t2 on t2.attrelid = cs.confrelid and t2.attnum = cs.confkey[1] and t2.attnum > 0 and not t2.attisdropped
        where trim(n.nspname) not in ('pg_catalog', 'information_schema')
      SQL
      sql += "and trim(n.nspname) = '%s'" unless schema_name.nil?
      sql += "and trim(c.relname) = '%s'" unless table_name.nil?
      self.class.select_all_grouped_by_table(sql, schema_name, table_name)
    end

    ##
    # proxy to `Reports::Base.select_all`
    #
    def self.select_all(sql, *args)
      Reports::Base.select_all(sql, *args)
    end
    private_class_method :select_all

    ##
    # groups results retrieved by `select_all` by
    # 'schema_name' and 'table_name' from the retrieved rows
    #
    def self.select_all_grouped_by_table(sql, *args)
      results = {}
      select_all(sql, *args).each do |result|
        fail 'Missing schema_name or table_name' unless result.has_key?('schema_name') && result.has_key?('table_name')
        full_table_name = "#{result['schema_name']}.#{result['table_name']}"
        results[full_table_name] ||= []
        results[full_table_name] << result
      end
      results
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
  puts Jobs::TableStructureExportJob.new('').execute(1, 1, schema_name: ARGV[0], table_name: ARGV[1], s3: {
    access_key_id: Sinatra::Configurations.aws('access_key_id'),
    secret_access_key: Sinatra::Configurations.aws('secret_access_key')
  })
end

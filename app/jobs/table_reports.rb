require './app/main'

module Jobs
  #
  # Job retrieving reports about RedShift tables
  #
  class TableReports < Desmond::BaseJob
    def self.logger
      @logger ||= PolizeiLogger.logger('tablereports')
    end
    def logger
      self.class.logger
    end

    ##
    # optional +options+:
    # - :schema_name
    # - :table_name
    # will update all reports if not given
    #
    def execute(job_id, user_id, options={})
      schema_name = options[:schema_name] || nil
      table_name  = options[:table_name] || nil
      table = { schema_name: schema_name, table_name: table_name } unless schema_name.nil? || table_name.nil?

      # get connection to RedShift
      c = PGUtil.dedicated_connection(system_connection_allowed: true)
      # execute update in transaction so that reports stay available
      reports = {}
      still_exists = true
      Models::TableReport.transaction do
        # check the saved reports for updates => deleting non-existant tables
        all_tables = get_all_table_names(c, table)
        existing_reports = Models::TableReport.all if table.nil?
        existing_reports = Models::TableReport.where(table) unless table.nil?
        existing_reports.each do |tr|
          tr.destroy if !all_tables.has_key?("#{tr['schema_name']}.#{tr['table_name']}")
        end
        # get and save new table reports
        reports = save_table_reports(c, table)
        still_exists = false if reports.nil?
      end
      still_exists
    ensure
      c.close
    end

    private

    def save_table_reports(connection, table)
      rs = get_table_reports(connection, table)
      full_table_name = "#{table[:schema_name]}.#{table[:table_name]}" unless table.nil?
      if !table.nil? && rs.empty? # requested table not found
        Models::TableReport.where(schema_name: table[:schema_name],
            table_name: table[:table_name]).destroy_all
        return nil
      end
      rs.hmap do |full_table_name, report|
        tr = Models::TableReport.where(schema_name: report[:schema_name],
            table_name: report[:table_name]).first_or_initialize
        tr.update(report)
      end
    end

    def get_table_reports(connection, table)
      statistics = execute_grouped_by_table(connection, 'tables/size_skew_populated', sql_append(table))
      col_encodings = has_column_encodings(connection, table)
      dist_styles = get_dist_styles(connection, table)
      sort_dist_keys = get_sort_and_dist_keys(connection, table)

      statistics.hmap do |full_table_name, stats|
        begin
          r = stats[0]
          col_encoding = col_encodings[full_table_name] || false
          dist_style = dist_styles[full_table_name]
          sort_dist_key = sort_dist_keys[full_table_name] || {}
          sort_key = sort_dist_key['sort_keys'] || []
          dist_key = sort_dist_key['dist_key']
          {
            schema_name: r['schema_name'].strip,
            table_name: r['table_name'].strip,
            table_id: r['table_id'].to_i,
            dist_style: dist_style['dist_style'],
            size_in_mb: r['size_in_mb'].to_i,
            pct_skew_across_slices: r['pct_skew_across_slices'].to_f,
            pct_slices_populated: r['pct_slices_populated'].to_f,
            sort_keys: sort_key.to_json,
            dist_key: dist_key,
            has_col_encodings: col_encoding
          }
        end
      end
    end

    def get_all_table_names(connection, table)
      execute_grouped_by_table(connection, 'tables/exists', sql_append(table))
    end

    def get_dist_styles(connection, table)
      tmp = execute_grouped_by_table(connection, 'tables/dist_style', sql_append(table))
      tmp.hmap do |full_table_name, result|
        result[0]
      end
    end

    def get_sort_and_dist_keys(connection, table)
      tmp = execute_grouped_by_table(connection, 'tables/sort_dist_keys', sql_append(table))
      tmp.hmap do |full_table_name, result|
        sort_keys = result.sort_by { |r| r['attsortkeyord'].to_i }.select { |r| (r['attsortkeyord'].to_i > 0) }.map do |r|
          r['attname']
        end
        dist_key = nil
        tmp = result.select { |r| (r['attisdistkey'] == 't') }
        dist_key = tmp[0]['attname'] if not tmp.empty?
        { 'sort_keys' => sort_keys, 'dist_key' => dist_key }
      end
    end

    def has_column_encodings(connection, table)
      tmp = execute_grouped_by_table(connection, 'tables/has_encoding', sql_append(table))
      tmp.hmap do |full_table_name, encoding_columns|
        !encoding_columns.empty?
      end
    end

    ##
    # returns option 'append' for `SQL.execute` for all used queries
    #
    def sql_append(table)
      return { append: nil } if table.nil? || table[:schema_name].nil? || table[:table_name].nil?
      return { append: ['and trim(n.nspname) = ? and trim(c.relname) = ?', table[:schema_name], table[:table_name]] }
    end

    ##
    # groups results retrieved by `SQL.execute` in a hash by
    # 'schema_name' and 'table_name' from the retrieved rows
    #
    def execute_grouped_by_table(*args)
      results = {}
      SQL.execute(*args).each do |result|
        fail 'Missing schema_name or table_name' unless result.has_key?('schema_name') && result.has_key?('table_name')
        full_table_name = "#{result['schema_name']}.#{result['table_name']}"
        results[full_table_name] ||= []
        results[full_table_name] << result
      end
      results
    end
  end
end

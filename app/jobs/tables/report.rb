require_relative '../../main'

module Jobs
  #
  # Job retrieving reports about RedShift tables
  #
  class TableReports < Desmond::BaseJob # TODO doesn't need job id
    extend Jobs::BaseReport
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
    # returns false if table does not exist anymore, true otherwise
    #
    def execute(job_id, user_id, options={})
      schema_name = options[:schema_name] || nil
      table_name  = options[:table_name] || nil
      table = { schema_name: schema_name, table_name: table_name } unless schema_name.nil? || table_name.nil?

      # get connection to RedShift
      reports = {}
      still_exists = true
      RSPool.with do |c|
        # execute update in transaction so that reports stay available
        Models::TableReport.transaction do
          # check the saved reports for updates => deleting non-existant tables
          all_tables = TableUtils.get_all_table_names(c, table)
          existing_reports = Models::TableReport.all if table.nil?
          existing_reports = Models::TableReport.where(table) unless table.nil?
          existing_reports.each do |tr|
            tr.destroy if !all_tables.has_key?("#{tr['schema_name']}.#{tr['table_name']}")
          end
          # get and save new table reports
          reports = save_table_reports(c, table)
          still_exists = false if reports.nil?
        end
      end
      still_exists
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
      statistics = TableUtils.get_size_skew_populated(connection, table)
      col_encodings = TableUtils.has_column_encodings(connection, table)
      sort_dist_styles = TableUtils.get_sort_and_dist_styles(connection, table)
      sort_dist_keys = TableUtils.get_sort_and_dist_keys(connection, table)

      statistics.hmap do |full_table_name, stats|
        begin
          r = stats[0]
          col_encoding    = col_encodings[full_table_name] || false
          sort_dist_style = sort_dist_styles[full_table_name] || {}
          sort_dist_key   = sort_dist_keys[full_table_name] || {}
          {
            schema_name: r['schema_name'].strip,
            table_name: r['table_name'].strip,
            table_id: r['table_id'].to_i,
            dist_style: sort_dist_style['dist_style'],
            sort_style: sort_dist_style['sort_style'],
            size_in_mb: r['size_in_mb'].to_i,
            pct_skew_across_slices: r['pct_skew_across_slices'].to_f,
            pct_slices_populated: r['pct_slices_populated'].to_f,
            sort_keys: (sort_dist_key['sort_keys'] || []).to_json,
            dist_key: sort_dist_key['dist_key'],
            has_col_encodings: col_encoding
          }
        end
      end
    end
  end
end

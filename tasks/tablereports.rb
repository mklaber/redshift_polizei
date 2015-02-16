require './app/main'

module Tasks
  #
  # Task retrieving reports about RedShift tables
  #
  class TableReports
    def self.logger
      if @logger.nil?
        @logger = PolizeiLogger.logger('tablereports')
        ActiveRecord::Base.logger = @logger
      end
      @logger
    end

    def self.run(tableids=nil)
      new.run(tableids)
    end

    def run(tableids=nil)
      self.class.logger.info "Updating Table Reports ..."
      if tableids.nil? || tableids.empty?
        # retrieve all the table ids to update
        results = self.class.select_all(<<-SQL
          SELECT DISTINCT(id) AS tableid
          FROM stv_tbl_perm
        SQL
        )
        tableids = results.map { |r| r['tableid'].to_i }
      end
      tableids = [tableids] if not(tableids.is_a?(Array))

      update_table_reports(tableids)
      self.class.logger.info "... done updating Table Reports"
    end

    private

    def update_table_reports(tableids)
      rs = get_table_reports(tableids)
      rs.each do |r|
        tr = Models::TableReport.where(schema_name: r[:schema_name],
          table_name: r[:table_name]).first_or_initialize
        tr.update_attributes(r)
        tr.save
      end
      return rs
    end

    def get_table_reports(tableids)
      sql = <<-SQL
        SELECT
          t0.schemaname,
          t0.tablename,
          t0.tableid,
          t0.diststyle,
          t1.size_in_mb,
          100 * CAST(t2.max_blocks_per_slice - t2.min_blocks_per_slice AS FLOAT)
              / CASE WHEN (t2.min_blocks_per_slice = 0)
                     THEN 1 ELSE t2.min_blocks_per_slice END AS pct_skew_across_slices,
          CAST(100 * t2.slice_count AS FLOAT) / (SELECT COUNT(*) FROM STV_SLICES) AS pct_slices_populated
        FROM
          (select distinct(id) AS tableid
          ,trim(nspname) AS schemaname
          ,trim(relname) AS tablename
          ,decode(pg_class.reldiststyle,0,'even',1,'key',8,'all') as diststyle
          from stv_tbl_perm
          join pg_class on pg_class.oid = stv_tbl_perm.id
          join pg_namespace on pg_namespace.oid = relnamespace) AS t0,
          (SELECT
            c.oid AS tableid,
            (SELECT COUNT(*) FROM STV_BLOCKLIST b WHERE b.tbl = c.oid) AS size_in_mb
          FROM pg_namespace n, pg_class c
          WHERE n.oid = c.relnamespace
          AND nspname NOT IN ('pg_catalog', 'pg_toast', 'information_schema')) AS t1,
          (SELECT tableid, MIN(c) AS min_blocks_per_slice, MAX(c) AS max_blocks_per_slice, COUNT(DISTINCT slice) AS slice_count
          FROM (SELECT pc.oid AS tableid, slice, COUNT(*) AS c
                FROM pg_class pc, STV_BLOCKLIST b
                WHERE pc.oid = b.tbl
                GROUP BY pc.relname, pc.oid, slice)
          GROUP BY tableid) AS t2
        WHERE t1.tableid = t2.tableid
        AND t2.tableid = t0.tableid
        AND t0.tableid IN (%s);
      SQL
      results = self.class.select_all(sql, tableids.join(','))

      results.map do |r|
        sortkeys, distkey = get_sort_and_dist_keys(r['tableid'])
        {
          schema_name: r['schemaname'].strip,
          table_name: r['tablename'].strip,
          table_id: r['tableid'],
          dist_style: r['diststyle'],
          size_in_mb: r['size_in_mb'].to_i,
          pct_skew_across_slices: r['pct_skew_across_slices'].to_f,
          pct_slices_populated: r['pct_slices_populated'].to_f,
          sort_keys: sortkeys.to_json,
          dist_key: distkey,
          has_col_encodings: has_column_encodings(r['tableid'])
        }
      end
    end

    def get_sort_and_dist_keys(tableid)
      sql = <<-SQL
        SELECT
          c.oid,
          a.attname,
          a.attsortkeyord,
          a.attisdistkey
        FROM pg_class c, pg_attribute a
        WHERE a.attrelid = c.oid
        AND (a.attsortkeyord > 0
        OR a.attisdistkey is true)
        AND c.oid = %d
        ORDER BY a.attsortkeyord ASC
      SQL
      result = self.class.select_all(sql, tableid)

      sortkeys = result.select { |r| (r['attsortkeyord'].to_i > 0) }.map do |r|
        r['attname']
      end
      distkey = nil
      tmp = result.select { |r| (r['attisdistkey'] == 't') }
      distkey = tmp[0]['attname'] if not tmp.empty?
      return sortkeys, distkey
    end

    def has_column_encodings(tableid)
      sql = <<-SQL
        SELECT *
        FROM pg_attribute a
        WHERE a.attrelid = %d
        AND a.attnum > 0
        AND NOT a.attisdropped
        AND a.attencodingtype <> 0
      SQL
      not(self.class.select_all(sql, tableid).empty?)
    end

    ##
    # proxy to `Reports::Base.select_all`
    #
    def self.select_all(sql, *args)
      Reports::Base.select_all(sql, *args)
    end
  end
end

if __FILE__ == $0
  Reports::Table.new.run(ARGV)
end

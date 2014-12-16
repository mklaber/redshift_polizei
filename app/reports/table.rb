require './app/main'

module Reports
  class Table < Base

    def run
      PolizeiLogger.logger.info "Updating Table Reports ..."
      results = self.class.select_all(<<-SQL
        SELECT
          t1.*,
          100 * CAST(t2.max_blocks_per_slice - t2.min_blocks_per_slice AS FLOAT)
              / CASE WHEN (t2.min_blocks_per_slice = 0)
                     THEN 1 ELSE t2.min_blocks_per_slice END AS pct_skew_across_slices,
          CAST(100 * t2.slice_count AS FLOAT) / (SELECT COUNT(*) FROM STV_SLICES) AS pct_slices_populated
        FROM
          (SELECT
            n.nspname AS schemaname,
            c.relname AS tablename,
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
        WHERE t1.tableid = t2.tableid;
      SQL
      )

      results.each do |r|
        tableid = r['tableid'].to_i
        sortkeys, distkey = get_sort_and_dist_keys(tableid)
        tr = Models::TableReport.where(schema_name: r['schemaname'],
          table_name: r['tablename']).first_or_initialize
        tr.update_attributes({
          schema_name: r['schemaname'],
          table_name: r['tablename'],
          table_id: tableid,
          size_in_mb: r['size_in_mb'].to_i,
          pct_skew_across_slices: r['pct_skew_across_slices'].to_f,
          pct_slices_populated: r['pct_slices_populated'].to_f,
          sort_keys: sortkeys.to_json,
          dist_key: distkey,
          has_col_encodings: has_column_encodings(tableid)
        })
        tr.save
      end
      PolizeiLogger.logger.info "... done updating Table Reports"
    end

    def retrieve
      Models::TableReport.order(size_in_mb: :desc)
    end

    private
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
  end
end

if __FILE__ == $0
  Reports::Table.new.run
end

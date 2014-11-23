module Reports
  class Table < Base

    def run
      sql = self.sanitize_sql(<<-SQL
      SELECT c.schemaname as schema, c.tablename as table, c.tableid, c.size_in_mb, 
      sort_key_1_attr.attname as sort_key_1,
      sort_key_2_attr.attname as sort_key_2,
      sort_key_3_attr.attname as sort_key_3,
      sort_key_4_attr.attname as sort_key_4,
      dist_key_attr.attname as dist_key,
      c.has_col_encoding, c.pct_skew_across_slices, c.pct_slices_populated
      FROM statistics.tables_report c 
      left join pg_attribute as sort_key_1_attr on sort_key_1_attr.attrelid = c.tableid and sort_key_1_attr.attsortkeyord = 1
      left join pg_attribute as sort_key_2_attr on sort_key_2_attr.attrelid = c.tableid and sort_key_2_attr.attsortkeyord = 2
      left join pg_attribute as sort_key_3_attr on sort_key_3_attr.attrelid = c.tableid and sort_key_3_attr.attsortkeyord = 3
      left join pg_attribute as sort_key_4_attr on sort_key_4_attr.attrelid = c.tableid and sort_key_4_attr.attsortkeyord = 4
      left join pg_attribute as dist_key_attr on dist_key_attr.attrelid = c.tableid and dist_key_attr.attisdistkey is true
      order by c.size_in_mb desc;
      SQL
      )

      @result = cache(sql, expires: 30) do
        self.redshift_select_all(sql)
      end
      @result.each do |row|
        row['sort_keys'] = []
        row.keys.select{|k| /^sort_key_[0-9]+$/ =~ k }.each{|k| row['sort_keys'] << row[k] if row[k].present? }        
      end
      @result
    end

  end
end

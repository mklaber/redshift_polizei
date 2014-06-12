module Reports
  class Table < Base
  
    attr_reader :options
  
    def initialize(unsanitized_options = {})
      # Ensure options are valid
      # this includes dealing with start_date, end_date
      @options = self.class.filter(unsanitized_options)
    end 
  	
    def result
      sql = <<-SQL
      SELECT c.schemaname as schema, c.tablename as table, c.tableid, c.size_in_mb, a.attname as sortkey, b.attname as distkey,
      c.has_col_encoding, c.pct_skew_across_slices, c.pct_slices_populated FROM statistics.tables_report c 
      left join 
      (select attname,attrelid from pg_attribute where attsortkeyord is true) as a
      on c.tableid = a.attrelid
      left join
      (select attname,attrelid from pg_attribute where attisdistkey is true) as b
      on c.tableid = b.attrelid
      order by c.size_in_mb desc;
      SQL
      @result = self.class.connection.select_all(self.class.sanitize([sql, @options]))
    end
  	
  end
end

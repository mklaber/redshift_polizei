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
        select * from statistics.tables_report
        order by size_in_mb desc;
      SQL
      @result = self.class.connection.select_all(self.class.sanitize([sql, @options]))
    end
  
  end
end

module Reports
  
  class DiskSpace < Base
  
    attr_reader :options
    
    def initialize(unsanitized_options = {})
      # Ensure options are valid
      # this includes dealing with start_date, end_date
      @options = self.class.filter(unsanitized_options)
    end 
  	
    def get_disk_space_info
        
        #We want to query disk space information for all the nodes
        sql = <<-SQL
            SELECT owner AS node, sum(used) AS used, sum(capacity) AS capacity
            FROM stv_partitions 
            GROUP BY node
            ORDER BY 1;
        SQL
        
        @results = self.class.connection.select_all(self.class.sanitize([sql, @options]))
        
    end
    
  end
end

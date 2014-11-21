module Reports
  class DiskSpace < Base
  	
    def run
        #We want to query disk space information for all the nodes
        sql = <<-SQL
            SELECT owner AS node, sum(used) AS used, sum(capacity) AS capacity
            FROM stv_partitions 
            GROUP BY node
            ORDER BY 1;
        SQL
        
        @results = self.select_all(sql)
    end
  end
end

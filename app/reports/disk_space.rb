module Reports
  #
  # Report retrieving disk space usage directly from cluster using SQL
  #
  class DiskSpace < Base

    #
    # retrieves disk usage and capacity from RedShift directly
    #
    def run
      #We want to query disk space information for all the nodes
      sql = self.class.sanitize_sql(<<-SQL
          SELECT owner AS node, sum(used) AS used, sum(capacity) AS capacity
          FROM stv_partitions
          GROUP BY node
          ORDER BY 1;
      SQL
      )

      @results = cache(sql) do
        self.class.select_all(sql).map do |node|
          {
            'node' => node['node'],
            'used' => node['used'].to_i,
            'capacity' => node['capacity'].to_i
          }
        end
      end
    end
  end
end

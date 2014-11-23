module Reports
  class DiskSpace < Base

    def run
      #We want to query disk space information for all the nodes
      sql = self.sanitize_sql(<<-SQL
          SELECT owner AS node, sum(used) AS used, sum(capacity) AS capacity
          FROM stv_partitions
          GROUP BY node
          ORDER BY 1;
      SQL
      )

      @results = cache(sql, expires: 30) do
        self.redshift_select_all(sql)
      end
    end
  end
end

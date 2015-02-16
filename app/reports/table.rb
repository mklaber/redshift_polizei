require './app/main'

module Reports
  class Table < Base

    def run(tableids=nil)
      Tasks::TableReports.run
    end

    def retrieve_all
      Models::TableReport.order(size_in_mb: :desc)
    end

    def update_one(tableid)
      update_table_reports([tableid])[0]
    end
  end
end

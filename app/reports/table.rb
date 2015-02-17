require './app/main'

module Reports
  class Table < Base

    # TODO remove this, still needed by reports update task
    def run(tableids=nil)
      Jobs::TableReports.run(1, 1)
    end
  end
end

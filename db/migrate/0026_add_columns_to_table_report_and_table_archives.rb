class AddColumnsToTableReportAndTableArchives < ActiveRecord::Migration
  def change
    add_column :table_reports, :columns, :json
    add_column :table_archives, :columns, :json
  end
end

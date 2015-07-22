class AddColumnsToTableReport < ActiveRecord::Migration
  def change
    add_column :table_reports, :columns, :json
  end
end

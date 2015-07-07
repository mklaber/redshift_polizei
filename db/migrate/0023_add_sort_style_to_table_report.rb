class AddSortStyleToTableReport < ActiveRecord::Migration
  def change
    add_column :table_reports, :sort_style, :string, :null => true
  end
end

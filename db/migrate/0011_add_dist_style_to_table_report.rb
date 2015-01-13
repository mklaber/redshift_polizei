class AddDistStyleToTableReport < ActiveRecord::Migration
  def change
    add_column :table_reports, :dist_style, :string, :null => true
  end
end

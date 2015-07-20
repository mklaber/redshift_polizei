class AddTableComments < ActiveRecord::Migration
  def change
    add_column :table_reports, :comment, :string, :null => true
    add_column :table_archives, :comment, :string, :null => true
  end
end

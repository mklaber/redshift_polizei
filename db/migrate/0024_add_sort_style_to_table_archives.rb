class AddSortStyleToTableArchives < ActiveRecord::Migration
  def change
    add_column :table_archives, :sort_style, :string, :null => true
  end
end

class AddTableCommentToTableReport < ActiveRecord::Migration
  def change
    add_column :table_reports, :comment, :string, :null => true
  end
end

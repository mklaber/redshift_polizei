class AddQueryType < ActiveRecord::Migration
  def up
    ActiveRecord::Base.connection.execute("TRUNCATE queries")
    add_column :queries, :query_type, :integer, :null => false
  end

  def down
    remove_column :queries, :query_type
  end
end

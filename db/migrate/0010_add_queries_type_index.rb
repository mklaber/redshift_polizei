class AddQueriesTypeIndex < ActiveRecord::Migration
  def change
    add_index :queries, :query_type
  end
end

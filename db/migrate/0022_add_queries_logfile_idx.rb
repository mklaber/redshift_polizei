class AddQueriesLogfileIdx < ActiveRecord::Migration
  def up
    add_index :queries, :logfile
  end

  def down
    remove_index :queries, :logfile
  end
end

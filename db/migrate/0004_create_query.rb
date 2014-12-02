class CreateQuery < ActiveRecord::Migration
  def change
    create_table(:queries) do |t|
      t.integer :record_time, :null => false
      t.string :db, :null => false
      t.string :user, :null => false
      t.integer :pid, :null => false
      t.integer :userid, :null => false
      t.integer :xid, :null => false
      t.text :query, :null => false
      t.string :logfile, :null => false
      t.timestamps
    end
  end
end

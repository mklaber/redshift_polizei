class CreateUsers < ActiveRecord::Migration
  def change
    create_table(:users) do |t|
      t.string :email, :null => false
      t.string :google_id, :null => false
      t.timestamps
    end

    add_index :users, :email, :unique => true
    add_index :users, :google_id, :unique => true
  end
end

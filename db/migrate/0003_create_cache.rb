class CreateCache < ActiveRecord::Migration
  using(:postgres)

  def change
    create_table(:cache) do |t|
      t.string :hashid, :null => false
      t.json :data, :null => false
      t.integer :expires, :null => true
      t.timestamps
    end

    add_index :cache, :hashid, :unique => true
  end
end

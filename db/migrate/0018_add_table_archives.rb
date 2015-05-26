class AddTableArchives < ActiveRecord::Migration
  def change
    create_table(:table_archives) do |t|
      t.string  :schema_name, null: false
      t.string  :table_name , null: false
      t.string  :archive_bucket, null: false
      t.string  :archive_prefix, null: false
      t.integer :size_in_mb, null: true
      t.string  :dist_key, null: true
      t.string  :dist_style, null: true
      t.json    :sort_keys, null: true
      t.boolean :has_col_encodings, null: true
      t.timestamps
    end

    add_index :table_archives, [:schema_name, :table_name], :unique => true
  end
end

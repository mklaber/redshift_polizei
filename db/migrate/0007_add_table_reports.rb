class AddTableReports < ActiveRecord::Migration
  def change
    create_table(:table_reports) do |t|
      t.string  :schema_name, null: false
      t.string  :table_name , null: false
      t.integer :table_id   , null: false
      t.integer :size_in_mb, null: false
      t.float   :pct_skew_across_slices, null: false
      t.float   :pct_slices_populated, null: false
      t.string  :dist_key, null: true
      t.json    :sort_keys, null: false
      t.boolean :has_col_encodings, null: false
      t.timestamps
    end

    add_index :table_reports, [:table_id], :unique => true
    add_index :table_reports, [:schema_name, :table_name], :unique => true
  end
end

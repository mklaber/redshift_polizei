class AddExportJobs < ActiveRecord::Migration
  def change
    create_table(:export_jobs) do |t|
      t.string  :name, null: false
      t.integer :user_id, null: false
      t.string  :success_email, null: true
      t.string  :failure_email, null: true
      t.boolean :public, null: false
      t.text    :query, null: false
      t.string  :export_format, null: false
      t.json    :export_options, null: false
      t.timestamps
    end
    add_index :export_jobs, :user_id
    add_index :export_jobs, :public

    create_table(:job_runs) do |t|
      t.integer   :job_id, null: false
      t.string    :job_class, null: false
      t.integer   :user_id, null: false
      t.string    :status, null: false
      t.datetime  :executed_at, null: true
      t.json      :details, null: false
      t.timestamps
    end
    add_index :job_runs, [:job_id, :job_class]
    add_index :job_runs, :user_id
  end
end

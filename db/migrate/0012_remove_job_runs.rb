class RemoveJobRuns < ActiveRecord::Migration
  def change
    drop_table :job_runs
  end
end

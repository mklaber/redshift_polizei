class CreateAuditLogConfig < ActiveRecord::Migration
  def change
    create_table(:audit_log_config) do |t|
      t.integer :retention_period, null: false, default: 30 * 86400 # 30 days
      t.integer :last_update, null: false, default: 0
      t.timestamps
    end
  end
end

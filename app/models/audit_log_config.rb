module Models
  #
  # Configuration for the audit log parser task
  #
  class AuditLogConfig < ActiveRecord::Base
    self.table_name = :audit_log_config
    # id                     :integer          not null, primary key
    # retention_period       :integer          not null, default 0
    # last_update            :integer          not null, default 0

    def self.get
      t = self.all.take
      if t.nil?
        self.create
        self.get
      else
        t
      end
    end
  end
end

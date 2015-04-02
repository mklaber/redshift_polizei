require_relative '../../../spec_helper'

describe Jobs::Queries::AuditLog::EnforceRetention do
  it 'should enforce retention period' do
    q = Models::Query.create!(
      record_time: Time.now - Models::AuditLogConfig.get.retention_period - 1,
      db: 'test_db', user: 'test_user',
      pid: 4, userid: 8, xid: 15, query: 'select * from tobias.test',
      logfile: 'logfile.log', query_type: 1)
    Jobs::Queries::AuditLog::EnforceRetention.run(0)
    expect { Models::Query.find(q.id) }.to raise_error(ActiveRecord::RecordNotFound)
  end
end

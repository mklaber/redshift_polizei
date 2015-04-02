require_relative '../../../spec_helper'

describe Jobs::Queries::AuditLog::Reclassify do
  it 'should reclassify a query' do
    q = Models::Query.create!(record_time: Time.now, db: 'test_db', user: 'test_user',
      pid: 4, userid: 8, xid: 15, query: 'select * from tobias.test',
      logfile: 'logfile.log', query_type: 1)
    Jobs::Queries::AuditLog::Reclassify.run(0)
    q.reload
    expect(q.query_type).to eq(0)
  end
end

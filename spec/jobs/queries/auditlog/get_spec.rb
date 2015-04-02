require_relative '../../../spec_helper'

describe Jobs::Queries::AuditLog::Get do
  before(:each) do
    Models::Query.destroy_all
  end

  it 'should get all queries' do
    q = Models::Query.create!(record_time: Time.now, db: 'test_db', user: 'test_user',
      pid: 4, userid: 8, xid: 15, query: 'select * from tobias.test',
      logfile: 'logfile.log', query_type: 0)
    result = Jobs::Queries::AuditLog::Get.run(0, selects: true, start: 0, length: 50)
    expect(result[:recordsTotal]).to eq(1)
    expect(result[:recordsFiltered]).to eq(1)
    expect(result[:data].size).to eq(1)
    expect(result[:data][0]['id']).to eq(q.id)
  end

  it 'should be able to ignore select queries' do
    q = Models::Query.create!(record_time: Time.now, db: 'test_db', user: 'test_user',
      pid: 4, userid: 8, xid: 15, query: 'select * from tobias.test',
      logfile: 'logfile.log', query_type: 0)
    result = Jobs::Queries::AuditLog::Get.run(0, selects: false, start: 0, length: 50)
    expect(result[:recordsTotal]).to eq(1)
    expect(result[:recordsFiltered]).to eq(0)
    expect(result[:data].size).to eq(0)
  end

  it 'should return number of results requested' do
    q1 = Models::Query.create!(record_time: Time.now, db: 'test_db', user: 'test_user',
      pid: 4, userid: 8, xid: 15, query: 'select * from tobias.test',
      logfile: 'logfile.log', query_type: 0)
    q2 = Models::Query.create!(record_time: Time.now + 1, db: 'test_db', user: 'faraday',
      pid: 4, userid: 8, xid: 15, query: 'select * from anyone.test',
      logfile: 'logfile.log', query_type: 0)
    result = Jobs::Queries::AuditLog::Get.run(0, selects: true, start: 0, length: 1, order: 0, orderdir: 'asc')
    expect(result[:recordsTotal]).to eq(2)
    expect(result[:recordsFiltered]).to eq(2)
    expect(result[:data].size).to eq(1)
    expect(result[:data][0]['id']).to eq(q1.id)
  end

  it 'should return ordered results' do
    q1 = Models::Query.create!(record_time: Time.now, db: 'test_db', user: 'test_user',
      pid: 4, userid: 8, xid: 15, query: 'select * from tobias.test',
      logfile: 'logfile.log', query_type: 0)
    q2 = Models::Query.create!(record_time: Time.now + 1, db: 'test_db', user: 'faraday',
      pid: 4, userid: 8, xid: 15, query: 'select * from anyone.test',
      logfile: 'logfile.log', query_type: 0)

    result = Jobs::Queries::AuditLog::Get.run(0, selects: true, start: 0, length: 50, order: 0, orderdir: 'asc')
    expect(result[:recordsTotal]).to eq(2)
    expect(result[:recordsFiltered]).to eq(2)
    expect(result[:data].size).to eq(2)
    expect(result[:data].map { |q| q['id'] }).to eq([q1.id, q2.id])

    result = Jobs::Queries::AuditLog::Get.run(0, selects: true, start: 0, length: 50, order: 0, orderdir: 'desc')
    expect(result[:recordsTotal]).to eq(2)
    expect(result[:recordsFiltered]).to eq(2)
    expect(result[:data].size).to eq(2)
    expect(result[:data].map { |q| q['id'] }).to eq([q2.id, q1.id])
  end

  it 'should return empty results with invalid length' do
    result = Jobs::Queries::AuditLog::Get.run(0, selects: true, start: 0, length: 0)
    expect(result[:recordsTotal]).to eq(0)
    expect(result[:recordsFiltered]).to eq(0)
    expect(result[:data].size).to eq(0)
  end

  it 'should support full-text search' do
    q1 = Models::Query.create!(record_time: Time.now, db: 'test_db', user: 'test_user',
      pid: 4, userid: 8, xid: 15, query: 'select * from tobias.test',
      logfile: 'logfile.log', query_type: 0)
    q2 = Models::Query.create!(record_time: Time.now, db: 'test_db', user: 'faraday',
      pid: 4, userid: 8, xid: 15, query: 'select * from anyone.test',
      logfile: 'logfile.log', query_type: 0)

    # searching for query term
    result = Jobs::Queries::AuditLog::Get.run(0, selects: true, start: 0, length: 50, search: 'tobias.test')
    expect(result[:recordsTotal]).to eq(2)
    expect(result[:recordsFiltered]).to eq(1)
    expect(result[:data].size).to eq(1)
    expect(result[:data][0]['id']).to eq(q1.id)
    # searching for user term
    result = Jobs::Queries::AuditLog::Get.run(0, selects: true, start: 0, length: 50, search: 'faraday')
    expect(result[:recordsTotal]).to eq(2)
    expect(result[:recordsFiltered]).to eq(1)
    expect(result[:data].size).to eq(1)
    expect(result[:data][0]['id']).to eq(q2.id)
    # searching for query term for both
    result = Jobs::Queries::AuditLog::Get.run(0, selects: true, start: 0, length: 50, search: 'select')
    expect(result[:recordsTotal]).to eq(2)
    expect(result[:recordsFiltered]).to eq(2)
    expect(result[:data].size).to eq(2)
    expect(result[:data].map { |q| q['id'] }).to match_array([q1.id, q2.id])
  end
end

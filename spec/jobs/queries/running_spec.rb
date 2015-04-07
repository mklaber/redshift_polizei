require_relative '../../spec_helper'

describe Jobs::Queries::Running do
  def running_tbl
    "#{@config[:test_schema]}.polizei_queries_running_test"
  end
  before(:all) do
    RSPool.with do |c|
      c.exec("drop table if exists #{running_tbl}")
      c.exec("create table #{running_tbl} (userid int, slice int, query int, pid int, starttime timestamp, suspended integer, text character(200), sequence integer)")
      c.exec("insert into #{running_tbl} values(1, 1, 1, 1, '2015-04-08 16:23:42', 0, 'select 1', 0)")
    end
  end
  after(:all) do
    RSPool.with do |c|
      c.exec("drop table if exists #{running_tbl}")
    end
  end

  it 'should find query that just ran' do
    q = Jobs::Queries::Running.run(0, table_overwrite: running_tbl)
    expect(q.size).to eq(1)
    expect(q[0]['query']).to eq('select 1')
  end
end

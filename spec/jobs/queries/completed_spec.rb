require_relative '../../spec_helper'

describe Jobs::Queries::Completed do
  it 'should find query that just ran' do
    # using time of the database server in case it has an offset to our time
    d = DateTime.strptime(RSPool.with { |c| c.exec('select getdate()') }.to_a[0]['getdate'], '%Y-%m-%d %H:%M:%s').to_time
    RSPool.with { |c| c.exec('select 1 from stv_recents limit 5') }
    q = Jobs::Queries::Completed.run(0, date: d - 10, nouserfilter: true)
    expect(q).to satisfy { |q| q.map { |q| q['query'] == 'select 1 from stv_recents limit 5' }.any? }
  end

  it 'should complain about missing date' do
    expect { Jobs::Queries::Completed.run(0) }.to raise_error(ArgumentError)
  end
end

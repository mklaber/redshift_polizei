require_relative '../../spec_helper'

describe Jobs::Queries::Completed do
  it 'should find query that just ran' do
    d = Time.now
    RSPool.with { |c| c.exec('select 1 from stv_recents limit 5') }
    q = Jobs::Queries::Completed.run(0, date: d - 10, nouserfilter: true)
    expect(q).to satisfy { |q| q.map { |q| q['query'] == 'select 1 from stv_recents limit 5' }.one? }
  end

  it 'should complan about missing date' do
    expect { Jobs::Queries::Completed.run(0) }.to raise_error(ArgumentError)
  end
end

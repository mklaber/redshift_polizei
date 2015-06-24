class LimitQueryLength < ActiveRecord::Migration
  def up
    # we are limiting the query length, since ts_vector can't grow infinitely
    # the chosen limit indexes every reasonable query we saw so far completly
    execute "DROP INDEX queries_query_fts_idx;"
    execute "CREATE INDEX queries_query_fts_idx ON queries USING gin(to_tsvector('english', left(query, 16384)))"
  end

  def down
    execute "DROP INDEX queries_query_fts_idx;"
    execute "CREATE INDEX queries_query_fts_idx ON queries USING gin(to_tsvector('english', query))"
  end
end

class AddQueriesFullTextSearchIndex < ActiveRecord::Migration
  def up
    execute "CREATE INDEX queries_query_fts_idx ON queries USING gin(to_tsvector('english', query))"
  end
  def down
    execute "DROP INDEX queries_query_fts_idx;"
  end
end

class AddQueriesFullTextSearchIndex2Fix < ActiveRecord::Migration
  def up
    execute "DROP INDEX queries_user_fts_idx;"
    execute "CREATE INDEX queries_user_fts_idx ON queries USING gin(to_tsvector('english', \"user\"))"
  end
  def down
    execute "DROP INDEX queries_user_fts_idx;"
    execute "CREATE INDEX queries_user_fts_idx ON queries USING gin(to_tsvector('english', 'user'))"
  end
end

class AddQueriesPgTrgmIndex < ActiveRecord::Migration
  def up
    execute "CREATE INDEX queries_query_trgm_idx ON queries USING gin(query gin_trgm_ops)"
  end
  def down
    execute "DROP INDEX queries_query_trgm_idx;"
  end
end

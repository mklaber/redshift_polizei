select
  t.schemaname as schema_name,
  t.tablename as table_name,
  u.usename as username,
  has_table_privilege(u.usename, t.schemaname || '.' || t.tablename, 'select') as has_select,
  has_table_privilege(u.usename, t.schemaname || '.' || t.tablename, 'delete') as has_delete,
  has_table_privilege(u.usename, t.schemaname || '.' || t.tablename, 'update') as has_update,
  has_table_privilege(u.usename, t.schemaname || '.' || t.tablename, 'references') as has_references,
  has_table_privilege(u.usename, t.schemaname || '.' || t.tablename, 'insert') as has_insert
from pg_tables t, pg_user u
where t.schemaname != 'pg_catalog'
and t.schemaname != 'pg_toast'
and t.schemaname != 'information_schema'

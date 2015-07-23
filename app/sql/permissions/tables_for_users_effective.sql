select *
from (
  select
    trim(n.nspname) as schema_name,
    trim(c.relname) as table_name,
    u.usename as username,
    has_table_privilege(u.usename, trim(n.nspname) || '.' || trim(c.relname), 'select') as has_select,
    has_table_privilege(u.usename, trim(n.nspname) || '.' || trim(c.relname), 'delete') as has_delete,
    has_table_privilege(u.usename, trim(n.nspname) || '.' || trim(c.relname), 'update') as has_update,
    has_table_privilege(u.usename, trim(n.nspname) || '.' || trim(c.relname), 'references') as has_references,
    has_table_privilege(u.usename, trim(n.nspname) || '.' || trim(c.relname), 'insert') as has_insert
  from pg_namespace n
  join pg_class c on n.oid = c.relnamespace
  cross join pg_user u
  -- filter out system tables, temp tables, and indexes
  where c.reltype != 0 and n.nspname not in ('pg_catalog', 'information_schema', 'pg_toast') and n.nspname not like 'pg_temp_%%'
)
where (has_select or has_delete or has_update or has_references or has_insert)

select
  trim(n.nspname) as schema_name,
  trim(c.relname) as table_name
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where trim(n.nspname) not in ('pg_catalog', 'pg_toast', 'information_schema')

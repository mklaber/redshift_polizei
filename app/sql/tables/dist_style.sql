select distinct
  trim(n.nspname) as schema_name,
  trim(c.relname) as table_name,
  decode(c.reldiststyle, 0, 'even', 1, 'key', 8, 'all') as dist_style
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where trim(n.nspname) not in ('pg_catalog', 'pg_toast', 'information_schema')

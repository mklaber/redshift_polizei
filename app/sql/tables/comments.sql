select
  trim(n.nspname) as schema_name,
  trim(c.relname) as table_name,
  d.description as comment
from pg_class c
join pg_description d on c.oid = d.objoid
join pg_namespace n on n.oid = c.relnamespace
-- filter out system tables, temp tables, and indexes
where c.reltype != 0 and n.nspname not in ('pg_catalog', 'information_schema', 'pg_toast') and n.nspname not like 'pg_temp_%%'

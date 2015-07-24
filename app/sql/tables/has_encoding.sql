select
  trim(n.nspname) as schema_name,
  trim(c.relname) as table_name,
  a.attname,
  a.attencodingtype
from pg_attribute a
join pg_class c on a.attrelid = c.oid
join pg_namespace n on n.oid = c.relnamespace
where a.attnum > 0
and not a.attisdropped
and a.attencodingtype <> 0
-- filter out system tables, temp tables, and indexes
and c.reltype != 0 and n.nspname not in ('pg_catalog', 'information_schema', 'pg_toast') and n.nspname not like 'pg_temp_%%'

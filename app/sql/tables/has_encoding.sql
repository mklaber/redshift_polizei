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
and trim(n.nspname) not in ('pg_catalog', 'pg_toast', 'information_schema')

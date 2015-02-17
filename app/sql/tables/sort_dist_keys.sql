select
  trim(n.nspname) as schema_name,
  trim(c.relname) as table_name,
  a.attname,
  a.attsortkeyord,
  a.attisdistkey
from pg_class c
join pg_attribute a on a.attrelid = c.oid
join pg_namespace n on n.oid = c.relnamespace
where (a.attsortkeyord > 0
or a.attisdistkey is true)
and not a.attisdropped
and trim(n.nspname) not in ('pg_catalog', 'pg_toast', 'information_schema')

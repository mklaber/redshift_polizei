select
  trim(n.nspname) as schema_name,
  trim(c.relname) as table_name,
  a.attname,
  abs(a.attsortkeyord) as attsortkeyord,
  a.attisdistkey
from pg_class c
join pg_attribute a on a.attrelid = c.oid
join pg_namespace n on n.oid = c.relnamespace
where (a.attsortkeyord != 0
or a.attisdistkey is true)
and not a.attisdropped
-- filter out system tables, temp tables, and indexes
and c.reltype != 0 and n.nspname not in ('pg_catalog', 'information_schema', 'pg_toast') and n.nspname not like 'pg_temp_%%'

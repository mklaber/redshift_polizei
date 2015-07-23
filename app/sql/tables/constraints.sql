select
  trim(n.nspname) as schema_name,
  trim(c.relname) as table_name,
  cs.conname as constraint_name,
  cs.contype as constraint_type,
  t1.attname as contraint_columnname,
  n2.nspname as ref_namespace,
  c2.relname as ref_tablename,
  t2.attname as ref_columnname
from pg_constraint cs
inner join pg_class c on cs.conrelid = c.oid
inner join pg_namespace n on n.oid = c.relnamespace
inner join pg_attribute t1 on t1.attrelid = cs.conrelid and t1.attnum = cs.conkey[1] and t1.attnum > 0 and not t1.attisdropped
left join pg_class c2 on cs.confrelid = c2.oid
left join pg_namespace n2 on n2.oid = c2.relnamespace
left join pg_attribute t2 on t2.attrelid = cs.confrelid and t2.attnum = cs.confkey[1] and t2.attnum > 0 and not t2.attisdropped
-- filter out system tables, temp tables, and indexes
where c.reltype != 0 and n.nspname not in ('pg_catalog', 'information_schema', 'pg_toast') and n.nspname not like 'pg_temp_%%'

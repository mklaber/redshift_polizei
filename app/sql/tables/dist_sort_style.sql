select distinct
  trim(n.nspname) as schema_name,
  trim(c.relname) as table_name,
  decode(c.reldiststyle, 0, 'even', 1, 'key', 8, 'all') as dist_style,
  -- sort style is interleaved when attsortkeyord is negative and positive for neighboring fields
  (case when exists(select * from pg_attribute a where a.attrelid = c.oid and a.attsortkeyord < 0)
    then 'interleaved'
    else
      -- sort style is compound when attsortkeyord is completly positive
      (case when exists(select * from pg_attribute a where a.attrelid = c.oid and a.attsortkeyord != 0)
        then 'compound'
        else null end)
    end) as sort_style
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where trim(n.nspname) not in ('pg_catalog', 'pg_toast', 'information_schema')

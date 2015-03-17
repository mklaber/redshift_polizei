select
  cols.ordinal_position as position,
  cols.table_schema as schema_name,
  cols.table_name,
  cols.ordinal_position,
  cols.column_name as name,
  cols.data_type as type,
  cols.character_maximum_length as varchar_len,
  cols.numeric_precision,
  cols.numeric_scale,
  cols.is_nullable,
  pg_get_expr(d1.adbin, d1.adrelid) as "default",
  format_encoding(a.attencodingtype::integer) as encoding,
  regexp_substr(regexp_substr(d2.adsrc, '''(.*)'''), '[0-9]+,[0-9]+') as "identity"
from information_schema.columns cols
join pg_class c on c.relname = cols.table_name
join pg_namespace n on n.oid = c.relnamespace and n.nspname = cols.table_schema
join pg_attribute a on a.attnum > 0 and not a.attisdropped and c.oid = a.attrelid and cols.column_name = a.attname
left join pg_attrdef d1 on a.attrelid = d1.adrelid and a.attnum = d1.adnum and d1.adsrc not like '%%"identity"(%%'
left join pg_attrdef d2 on a.attrelid = d2.adrelid and a.attnum = d2.adnum and d2.adsrc like '%%"identity"(%%'
where trim(n.nspname) not in ('pg_catalog', 'pg_toast', 'information_schema')

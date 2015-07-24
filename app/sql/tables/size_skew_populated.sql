select
  trim(n.nspname) as schema_name,
  trim(c.relname) as table_name,
  c.oid as table_id,
  t1.size_in_mb,
  100 * cast(t2.max_blocks_per_slice - t2.min_blocks_per_slice as float)
      / case when (t2.min_blocks_per_slice = 0)
             then 1 else t2.min_blocks_per_slice end as pct_skew_across_slices,
  cast(100 * t2.slice_count as float) / (select count(*) from stv_slices) as pct_slices_populated
from pg_namespace n
join pg_class c on n.oid = c.relnamespace
left join (select
    c.oid as tableid,
    trim(n.nspname) as schemaname,
    trim(c.relname) as tablename,
    (select count(*) from stv_blocklist b where b.tbl = c.oid) as size_in_mb
  from pg_namespace n
  join pg_class c on n.oid = c.relnamespace) as t1 on c.oid = t1.tableid
left join (select tableid, min(c) AS min_blocks_per_slice, max(c) as max_blocks_per_slice, count(distinct slice) as slice_count
  from (select pc.oid AS tableid, slice, count(*) as c
        from pg_class pc
        join stv_blocklist b on pc.oid = b.tbl
        group by pc.relname, pc.oid, slice)
  group by tableid) as t2 on t1.tableid = t2.tableid
-- filter out system tables, temp tables, and indexes
where c.reltype != 0 and n.nspname not in ('pg_catalog', 'information_schema', 'pg_toast') and n.nspname not like 'pg_temp_%%'

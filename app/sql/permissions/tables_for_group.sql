-- this query is a handful.
-- it parses the ACL objects in the pg_class system table
-- ACL example: [grantee=permissions/granter, ...]
-- available permissions:
--   r => select
--   d => delete
--   w => update
--   x => reference
--   a => insert
--   ... for more check PG documentation
SELECT
  trim(n.nspname) as schema_name,
  trim(c.relname) AS table_name,
  case when charindex('r', split_part(split_part(array_to_string(c.relacl, '|'), ?, 2), '/', 1)) > 0 then 't' else 'f' end as has_select,
  case when charindex('d', split_part(split_part(array_to_string(c.relacl, '|'), ?, 2), '/', 1)) > 0 then 't' else 'f' end as has_delete,
  case when charindex('w', split_part(split_part(array_to_string(c.relacl, '|'), ?, 2), '/', 1)) > 0 then 't' else 'f' end as has_update,
  case when charindex('x', split_part(split_part(array_to_string(c.relacl, '|'), ?, 2), '/', 1)) > 0 then 't' else 'f' end as has_references,
  case when charindex('a', split_part(split_part(array_to_string(c.relacl, '|'), ?, 2), '/', 1)) > 0 then 't' else 'f' end as has_insert
FROM pg_catalog.pg_class c
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
where trim(n.nspname) not in ('pg_catalog', 'pg_toast', 'information_schema')
and array_to_string(c.relacl, '|') like ?;

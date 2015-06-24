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
select *
from (
  select
    schema_name,
    table_name,
    grantee,
    split_part(perms, '/', 2) as granter,
    case when charindex('r', split_part(perms, '/', 1)) > 0 then true else false end as has_select,
    case when charindex('d', split_part(perms, '/', 1)) > 0 then true else false end as has_delete,
    case when charindex('w', split_part(perms, '/', 1)) > 0 then true else false end as has_update,
    case when charindex('x', split_part(perms, '/', 1)) > 0 then true else false end as has_references,
    case when charindex('a', split_part(perms, '/', 1)) > 0 then true else false end as has_insert,
    relacl
  from (
    select
      schema_name,
      table_name,
      grantee,
      case when len(first_acl) = 0 then other_acl else first_acl end as perms,
      relacl
    from(
      select
        trim(n.nspname) as schema_name,
        trim(c.relname) AS table_name,
        u.usename as grantee,
        -- check if the first acl entry is for the user we're searching for
        split_part(split_part(array_to_string(c.relacl, '|'), '|', 1), u.usename || '=', 2)  as first_acl,
        -- check if any acl entry except the first is for the user we're searching for
        split_part(split_part(array_to_string(c.relacl, '|'), '|' || u.usename || '=', 2), '|', 1) as other_acl,
        c.relacl
      from pg_catalog.pg_class c
      join pg_catalog.pg_namespace n on n.oid = c.relnamespace
      cross join pg_catalog.pg_user u
      where trim(n.nspname) not in ('pg_catalog', 'pg_toast', 'information_schema')
      and array_to_string(c.relacl, '|') like '%%' || u.usename || '=%%'
    )
  )
)
where has_select or has_delete or has_update or has_references or has_insert

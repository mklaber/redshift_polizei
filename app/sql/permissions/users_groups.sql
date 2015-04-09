select
  u.usesysid as user_id,
  u.usename as username,
  g.grosysid as group_id,
  nvl(g.groname, 'default') AS group,
  u.usesuper as is_superuser
from pg_user u
left join pg_group g
on ','||array_to_string(g.grolist,',')||',' like '%%,'||cast(u.usesysid as varchar(10))||',%%'
where 1

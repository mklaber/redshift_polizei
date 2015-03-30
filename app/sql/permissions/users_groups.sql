select
  usesysid as user_id,
  usename as username,
  nvl(groname, 'default') AS group,
  usesuper as is_superuser
from pg_user u
left join pg_group g
on ','||array_to_string(grolist,',')||',' like '%%,'||cast(usesysid as varchar(10))||',%%'
where 1

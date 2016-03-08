select
  q.query as query_id,
  q.userid as user_id,
  q.pid,
  q.starttime as start_time,
  q.suspended,
  left(q.text, 2048) as query,
  q.sequence,
  trim(u.usename) as username
-- using svv_query_inflight instead of alternatives because
-- it can return the whole query text untruncated
from svv_query_inflight q
join pg_user u on q.userid = u.usesysid
where trim(u.usename) <> 'rdsdb' -- database internal user
and trim(u.usename) <> ? -- filter our own user
-- filter out queries we will never care about
and trim(q.text) not ilike 'set client_encoding to \'%\''
and trim(q.text) not ilike 'set datestyle to \'%\''
and trim(q.text) not ilike 'analyze compression phase%'
and trim(q.text) not ilike 'show time zone'
and trim(q.text) not ilike 'show search_path'
and trim(q.text) not ilike 'commit'
-- this sorting is important to be able to join the sequences again.
-- first by start_time to seperate the obviously different queries.
-- then by pid, to seperate queries which might have started at the same time.
-- and finally by sequence to have them all nicely ordered.
order by start_time desc, pid asc, sequence asc

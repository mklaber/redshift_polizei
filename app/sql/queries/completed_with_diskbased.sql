select
  q.query,
  q.userid as user_id,
  q.pid,
  q.starttime as start_time,
  q.endtime as end_time,
  d.is_diskbased,
  q.text as query,
  q.sequence,
  trim(u.usename) as username
-- svl_statementtext contains all queries (including ddl and utility) untruncated
-- custom svl_statementtext union, to get query ids
from (
    (SELECT NULL as query, stl_ddltext.userid, stl_ddltext.xid, stl_ddltext.pid, stl_ddltext."label", stl_ddltext.starttime, stl_ddltext.endtime, stl_ddltext."sequence", 'DDL'::character varying::character varying(10) AS "type", stl_ddltext.text
     FROM stl_ddltext
  UNION ALL 
   SELECT NULL as query, stl_utilitytext.userid, stl_utilitytext.xid, stl_utilitytext.pid, stl_utilitytext."label", stl_utilitytext.starttime, stl_utilitytext.endtime, stl_utilitytext."sequence", 'UTILITY'::character varying::character varying(10) AS "type", stl_utilitytext.text
     FROM stl_utilitytext)
  UNION ALL 
   SELECT stl_query.query, stl_query.userid, stl_query.xid, stl_query.pid, stl_query."label", stl_query.starttime, stl_query.endtime, stl_querytext."sequence", 'QUERY'::character varying::character varying(10) AS "type", stl_querytext.text
     FROM stl_query, stl_querytext
    WHERE stl_query.query = stl_querytext.query
) as q
left join (
  select query, is_diskbased from SVL_QUERY_SUMMARY where is_diskbased = 't'
) as d on d.query = q.query
join pg_user as u on q.userid = u.usesysid
where trim(u.usename) <> 'rdsdb' -- database internal user
and trim(u.usename) <> ? -- filter our own user
-- these query groups contain internal RedShift queries
and q.label <> 'metrics'
and q.label <> 'health'
-- filter out queries we will never care about
and lower(q.text) not like 'set client_encoding to \'%\''
and lower(q.text) <> 'show time zone'
and lower(q.text) <> 'show search_path'
and lower(q.text) <> 'commit'
and timestamp_cmp(q.starttime, ?) >= 0
-- this sorting is important to be able to join the sequences again.
-- first by start_time to seperate the obviously different queries.
-- then by pid, to seperate queries which might have started at the same time.
-- and finally by sequence to have them all nicely ordered.
order by start_time desc, pid asc, sequence asc

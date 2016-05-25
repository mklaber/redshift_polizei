SELECT DISTINCT(r.ev_class::regclass) AS views
           FROM pg_depend d JOIN pg_rewrite r ON r.oid = d.objid
           WHERE refclassid = 'pg_class'::regclass
           AND refobjid = ?::regclass
           AND classid = 'pg_rewrite'::regclass

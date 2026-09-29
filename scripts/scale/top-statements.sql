-- The statements that took the most database time in the last benchmark,
-- including those inside the app's SQL functions (pg_stat_statements with
-- track = all, set on the scratch database by prepare-scale-db.sh).
select round(total_exec_time)::bigint as total_ms,
  calls,
  round(mean_exec_time::numeric, 2) as mean_ms,
  round((100 * total_exec_time / sum(total_exec_time) over ())::numeric, 1) as pct,
  left(regexp_replace(query, '\s+', ' ', 'g'), 150) as statement
from extensions.pg_stat_statements
where dbid = (select oid from pg_database where datname = current_database())
  and query not ilike '%set_config%' and query not ilike 'begin%' and query not ilike 'commit%'
  and query not ilike 'select private.%' and query not ilike 'select extensions.%'
order by total_exec_time desc
limit 15;

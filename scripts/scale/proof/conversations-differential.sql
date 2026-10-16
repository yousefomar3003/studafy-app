-- Zero-difference proof for the conversations list (capacity fix 5,
-- 2026-10-15), as differential.sql does for the academic lists. In ONE
-- transaction: record every case's answer, apply the migration, record
-- again, compare, roll back.
--
-- psql -v migration=<file> -v sample=<N> [-v plant=plant-conversations.sql]
--   -f conversations-differential.sql <db>
--   sample: keep users whose id hashes to 0 mod N (1 = every user).
\set ON_ERROR_STOP on
\pset pager off
begin;
set local statement_timeout = 0;
\if :{?pre1}
\i :pre1
\endif
\if :{?plant}
\i :plant
\endif

create temp table subjects as
select u.id as uid from auth.users u
where (abs(hashtext(u.id::text)) % :sample) = 0;

-- Every sampled person, with a page of 20, a page of 2 and a page of 1 (so
-- the keyset walks several pages and meets ties), and once with a malformed
-- position, which the list treats as none.
create temp table cases (n bigserial primary key, uid uuid, op text, resource uuid, input jsonb);
insert into cases(uid, op, resource, input)
select s.uid, 'listConversations', null, jsonb_build_object('pageSize', ps)
from subjects s cross join unnest(array[20, 2, 1]) ps;
insert into cases(uid, op, resource, input)
select s.uid, 'listConversations', null, '{"pageSize":20,"position":"not a position"}'::jsonb
from subjects s;

select count(*) as cases, count(distinct uid) as people from cases \gset
\echo cases :cases people :people

create function pg_temp.run(p_uid uuid, p_op text, p_resource uuid, p_input jsonb)
returns jsonb language plpgsql as $$
declare r jsonb; pages jsonb := '[]'; inp jsonb := p_input; i int := 0;
begin
  perform set_config('request.jwt.claim.sub', p_uid::text, true);
  perform set_config('studafy.school_id', '', true);
  loop
    begin
      r := private.api042_query(p_op, p_resource, inp);
    exception when others then
      r := jsonb_build_object('error', sqlstate);
    end;
    pages := pages || jsonb_build_array(r);
    i := i + 1;
    exit when i >= 6 or r->>'nextPosition' is null;
    inp := inp || jsonb_build_object('position', r->>'nextPosition');
  end loop;
  return pages;
end $$;

\timing on
create temp table before_out as select n, pg_temp.run(uid, op, resource, input) as out from cases;
\timing off

\i :migration

\timing on
create temp table after_out as select n, pg_temp.run(uid, op, resource, input) as out from cases;
\timing off

select count(*) as compared,
  count(*) filter (where b.out is distinct from a.out) as differences,
  sum(jsonb_array_length(b.out)) as pages,
  sum((select coalesce(sum(jsonb_array_length(p->'items')), 0)
       from jsonb_array_elements(b.out) p where jsonb_typeof(p->'items') = 'array')) as rows_compared,
  count(*) filter (where b.out::text like '%"error"%') as error_cases
from before_out b join after_out a using (n);

-- What the conversations compared actually contained.
select count(*) as conversation_rows,
  count(distinct i->>'id') as distinct_conversations,
  count(*) filter (where i->>'lastReadAt' is not null) as with_read_marker,
  sum(jsonb_array_length(i->'participants')) as participants,
  sum((select count(*) from jsonb_array_elements(i->'participants') x where x->>'role' = 'staff')) as staff,
  sum((select count(*) from jsonb_array_elements(i->'participants') x where x->>'role' = 'student')) as students,
  sum((select count(*) from jsonb_array_elements(i->'participants') x where x->>'role' = 'guardian')) as guardians,
  count(*) filter (where (select count(*) from jsonb_array_elements(i->'participants') x
    where x->>'displayName' = 'Sam Same') > 1) as with_same_names
from before_out b
cross join lateral jsonb_array_elements(b.out) pg
cross join lateral jsonb_array_elements(case when jsonb_typeof(pg->'items') = 'array' then pg->'items' else '[]' end) i;

select c.op, c.input->>'pageSize' as page_size, count(*) as cases,
  count(*) filter (where b.out is distinct from a.out) as differences
from cases c join before_out b using (n) join after_out a using (n)
group by 1, 2 order by 1, 2;

select c.n, c.uid, c.op, c.input, left(b.out::text, 300) as before, left(a.out::text, 300) as after
from cases c join before_out b using (n) join after_out a using (n)
where b.out is distinct from a.out limit 5;

rollback;

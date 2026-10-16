-- Conversation extras the synthetic data lacks, so the fix 5 proof meets
-- every participant role and every field: guardians and staff from other
-- schools in a class conversation, teachers whose membership has lapsed,
-- is suspended, ended or has not started, student records deleted, people
-- who left, read markers, two people with the same name, direct
-- conversations so lists run to several pages, and conversations with the
-- same last activity (now()), so the keyset meets ties. Runs inside the
-- differential's transaction and is rolled back with it.
--
-- :conversation_every picks how many conversations get extras (1 = every
-- one, for the pgTAP fixtures; the scale data uses 5).
\if :{?conversation_every} \else \set conversation_every 5 \endif

-- The pgTAP fixtures leave no conversations behind; -v seed_conversations=1
-- first makes, in each school, one conversation with everyone in it (its
-- members and their students' guardians) and one between every two of them.
\if :{?seed_conversations}
create temp table plant_people as
select distinct m.school_id, m.user_id from public.memberships m
union
select st.school_id, gl.guardian_id from public.guardian_links gl
join public.students st on st.id = gl.student_id;
insert into public.conversations (id, school_id, subject, state, created_by)
select ('0000' || substr(md5(p.school_id::text || ':all'), 5))::uuid, p.school_id, 'Everyone',
  'active', min(p.user_id::text)::uuid
from plant_people p group by p.school_id;
insert into public.conversation_participants (school_id, conversation_id, user_id)
select p.school_id, ('0000' || substr(md5(p.school_id::text || ':all'), 5))::uuid, p.user_id
from plant_people p;
insert into public.conversations (id, school_id, subject, state, created_by)
select ('0000' || substr(md5(a.user_id::text || ':' || b.user_id || ':' || a.school_id), 5))::uuid,
  a.school_id, null, 'active', a.user_id
from plant_people a join plant_people b on b.school_id = a.school_id and b.user_id > a.user_id;
insert into public.conversation_participants (school_id, conversation_id, user_id)
select a.school_id, ('0000' || substr(md5(a.user_id::text || ':' || b.user_id || ':' || a.school_id), 5))::uuid,
  u.user_id
from plant_people a join plant_people b on b.school_id = a.school_id and b.user_id > a.user_id
cross join lateral (values (a.user_id), (b.user_id)) u(user_id);
\endif

create temp table plant_conversations as
select c.id, c.school_id, c.created_by,
  abs(hashtext(c.id::text || ':case')) % 6 as kind
from public.conversations c
where abs(hashtext(c.id::text || ':pick')) % :conversation_every = 0;

-- Kind 0: each student's guardians join, and a teacher of another school.
insert into public.conversation_participants (school_id, conversation_id, user_id)
select distinct p.school_id, p.id, gl.guardian_id
from plant_conversations p
join public.conversation_participants cp on cp.conversation_id = p.id
join public.students st on st.user_id = cp.user_id
join public.guardian_links gl on gl.student_id = st.id and gl.status = 'verified'
where p.kind = 0
on conflict do nothing;
insert into public.conversation_participants (school_id, conversation_id, user_id)
select p.school_id, p.id, o.user_id
from plant_conversations p
cross join lateral (
  select m.user_id from public.memberships m
  where m.school_id <> p.school_id and m.role = 'teacher'
  order by m.user_id limit 1) o
where p.kind = 0
on conflict do nothing;

-- Kind 1: the teacher's membership lapses, is suspended, has ended or has
-- not started yet, by conversation.
update public.memberships m set
  active = case when abs(hashtext(p.id::text)) % 4 = 0 then false else m.active end,
  status = case when abs(hashtext(p.id::text)) % 4 = 1 then 'suspended' else m.status end,
  valid_until = case when abs(hashtext(p.id::text)) % 4 = 2 then now() - interval '1 day' else m.valid_until end,
  valid_from = case when abs(hashtext(p.id::text)) % 4 = 3 then now() + interval '1 day'
    when abs(hashtext(p.id::text)) % 4 = 2 then now() - interval '30 days' else m.valid_from end
from plant_conversations p
where p.kind = 1 and m.user_id = p.created_by and m.school_id = p.school_id;

-- Guardians in the picked conversations who also teach in that school, in
-- every state a membership can be in: current (open-ended or with an end
-- date), ended, ended the day it began, not started, suspended. Only the
-- first two make them staff in that conversation.
insert into public.memberships (school_id, user_id, role, active, status, valid_from, valid_until)
select g.school_id, g.user_id, 'teacher', g.v <> 4,
  case g.v when 4 then 'suspended' else 'active' end::public.membership_status,
  case g.v when 3 then now() + interval '1 day' else now() - interval '30 days' end,
  case g.v when 1 then now() + interval '30 days' when 2 then now() - interval '1 day'
    when 5 then now() - interval '30 days' end
from (
  select distinct p.school_id, cp.user_id,
    abs(hashtext(cp.user_id::text || ':' || p.school_id::text)) % 7 as v
  from plant_conversations p
  join public.conversation_participants cp on cp.conversation_id = p.id
  where exists (select 1 from public.guardian_links gl where gl.guardian_id = cp.user_id)
    and not exists (select 1 from public.students st where st.user_id = cp.user_id)
) g
where g.v < 6
on conflict do nothing;

-- Kind 2: some students' records are deleted.
update public.students st set deleted_at = now()
from plant_conversations p, public.conversation_participants cp
where p.kind = 2 and cp.conversation_id = p.id and st.user_id = cp.user_id
  and st.school_id = p.school_id and abs(hashtext(cp.user_id::text)) % 3 = 0;

-- Kind 3: some people left; some have read up to a point.
update public.conversation_participants cp set joined_at = now() - interval '3 hours', left_at = now() - interval '1 hour'
from plant_conversations p
where p.kind = 3 and cp.conversation_id = p.id and abs(hashtext(cp.user_id::text)) % 4 = 0;
update public.conversation_participants cp set last_read_at = now() - interval '2 hours'
from plant_conversations p
where p.kind in (3, 4) and cp.conversation_id = p.id and abs(hashtext(cp.user_id::text)) % 2 = 0;

-- Kind 4: two participants share a name, so their order falls to the id.
update public.profiles pr set display_name = 'Sam Same'
from plant_conversations p, public.conversation_participants cp
where p.kind = 4 and cp.conversation_id = p.id and pr.id = cp.user_id
  and abs(hashtext(cp.user_id::text)) % 5 = 0;

-- Kind 5: direct conversations between the teacher and each student, so a
-- student's list runs past a page of two, all active now (a tie).
insert into public.conversations (id, school_id, subject, state, created_by)
select ('0000' || substr(md5(p.id::text || ':' || cp.user_id), 5))::uuid, p.school_id,
  'Direct', 'active', p.created_by
from plant_conversations p
join public.conversation_participants cp on cp.conversation_id = p.id and cp.user_id <> p.created_by
where p.kind = 5;
insert into public.conversation_participants (school_id, conversation_id, user_id)
select p.school_id, ('0000' || substr(md5(p.id::text || ':' || cp.user_id), 5))::uuid, u.user_id
from plant_conversations p
join public.conversation_participants cp on cp.conversation_id = p.id and cp.user_id <> p.created_by
cross join lateral (values (p.created_by), (cp.user_id)) u(user_id)
where p.kind = 5
on conflict do nothing;

-- Every picked conversation was active just now: equal times for the keyset.
update public.conversations c set subject = coalesce(c.subject, '') || ' (planted)'
from plant_conversations p where p.id = c.id and p.kind in (0, 3);

analyze public.conversations, public.conversation_participants, public.memberships,
  public.students, public.profiles;

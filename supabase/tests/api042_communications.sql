begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(21);

select ok(
  has_function_privilege('studafy_api_runtime', 'private.api042_command(text,uuid,jsonb,uuid,bigint)', 'execute')
  and has_function_privilege('studafy_api_runtime', 'private.api042_query(text,uuid,jsonb)', 'execute'),
  'runtime can execute the communications query and command entry points'
);

create temporary table api042_comms_results(name text primary key, result jsonb);

-- --------------------------------------------------------------------------
-- createConversation
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.school_id', '', true);
select set_config('studafy.request_id', 'api042-create-convo-unverified', true);
insert into api042_comms_results values('convo-unverified-reservation', private.api_idempotency_reserve(
  null, 'v1.createConversation', 'api042-convo-unverified-1', repeat('a', 64)));
insert into api042_comms_results values('convo-unverified', private.api042_command(
  'createConversation', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'participantIds', jsonb_build_array(:'unverified_guardian'))),
  ((select result->>'id' from api042_comms_results where name = 'convo-unverified-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_comms_results where name = 'convo-unverified'), 'invalid',
  'an unverified guardian cannot be added as a conversation participant');

select set_config('studafy.request_id', 'api042-create-convo-cross-school', true);
insert into api042_comms_results values('convo-cross-reservation', private.api_idempotency_reserve(
  null, 'v1.createConversation', 'api042-convo-cross-1', repeat('b', 64)));
insert into api042_comms_results values('convo-cross', private.api042_command(
  'createConversation', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'participantIds', jsonb_build_array(:'other_school_user'))),
  ((select result->>'id' from api042_comms_results where name = 'convo-cross-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_comms_results where name = 'convo-cross'), 'invalid',
  'a member of a different school cannot be added as a participant');

select set_config('studafy.request_id', 'api042-create-convo', true);
insert into api042_comms_results values('convo-reservation', private.api_idempotency_reserve(
  null, 'v1.createConversation', 'api042-convo-key-01', repeat('c', 64)));
insert into api042_comms_results values('convo', private.api042_command(
  'createConversation', null, jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'subject', 'About homework', 'participantIds', jsonb_build_array(:'guardian_user'))),
  ((select result->>'id' from api042_comms_results where name = 'convo-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_comms_results where name = 'convo'), 'ok',
  'a teacher creates a conversation with a verified guardian');
select (result->'response'->>'id')::uuid as conversation_id from api042_comms_results where name = 'convo' \gset
select is(
  (select count(*) from public.conversation_participants where conversation_id = :'conversation_id'),
  2::bigint, 'the conversation has exactly the creator and the named participant');

-- --------------------------------------------------------------------------
-- listConversations
-- --------------------------------------------------------------------------

select ok(
  (private.api042_query('listConversations', null, '{}'::jsonb)->'items')::text like '%' || :'conversation_id' || '%',
  'the teacher sees the conversation they created'
);
select set_config('request.jwt.claim.sub', :'admin_user', true);
select ok(
  not ((private.api042_query('listConversations', null, '{}'::jsonb)->'items')::text like '%' || :'conversation_id' || '%'),
  'a non-participant admin does not see the conversation'
);

-- --------------------------------------------------------------------------
-- sendMessage / listMessages
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.school_id', :'school_id', true);
select set_config('studafy.request_id', 'api042-send-denied', true);
insert into api042_comms_results values('send-denied-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.sendMessage', 'api042-send-denied-1', repeat('d', 64)));
insert into api042_comms_results values('send-denied', private.api042_command(
  'sendMessage', :'conversation_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'clientMessageId', gen_random_uuid(), 'body', 'Hello?')),
  ((select result->>'id' from api042_comms_results where name = 'send-denied-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_comms_results where name = 'send-denied'), 'not_found',
  'a non-participant cannot send a message and cannot tell the conversation exists');

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.request_id', 'api042-send', true);
\set client_message_id '11110000-1111-4111-8111-111111111111'
insert into api042_comms_results values('send-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.sendMessage', 'api042-send-key-01', repeat('e', 64)));
insert into api042_comms_results values('send', private.api042_command(
  'sendMessage', :'conversation_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'clientMessageId', :'client_message_id', 'body', 'Please review the homework.')),
  ((select result->>'id' from api042_comms_results where name = 'send-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_comms_results where name = 'send'), 'ok',
  'a participant sends a message');
select (result->'response'->>'id')::uuid as message_id from api042_comms_results where name = 'send' \gset

-- A retry with a different idempotency key but the same client_message_id
-- must resolve to the same domain row (client-generated-id dedup), not just
-- the idempotency-key replay path.
select set_config('studafy.request_id', 'api042-send-retry', true);
insert into api042_comms_results values('send-retry-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.sendMessage', 'api042-send-retry-1', repeat('f', 64)));
insert into api042_comms_results values('send-retry', private.api042_command(
  'sendMessage', :'conversation_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'clientMessageId', :'client_message_id', 'body', 'Please review the homework.')),
  ((select result->>'id' from api042_comms_results where name = 'send-retry-reservation')::uuid), 1));
select is((select result->'response'->>'id' from api042_comms_results where name = 'send-retry'), :'message_id'::text,
  'resending the same client_message_id under a fresh idempotency key resolves to the same message, not a duplicate');
select is((select count(*) from public.messages where conversation_id = :'conversation_id'), 1::bigint,
  'exactly one message row exists despite two send attempts');

select is((private.api042_query('listMessages', :'conversation_id', '{}'::jsonb)->'items')::text like '%' || :'message_id' || '%', true,
  'a participant lists the sent message');

select set_config('request.jwt.claim.sub', :'admin_user', true);
select is(private.api042_query('listMessages', :'conversation_id', '{}'::jsonb)->>'outcome', 'not_found',
  'a non-participant cannot list messages and cannot tell the conversation exists');

-- --------------------------------------------------------------------------
-- createAnnouncement / listAnnouncements
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.request_id', 'api042-announce-school-denied', true);
insert into api042_comms_results values('announce-school-denied-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.createAnnouncement', 'api042-announce-school-denied-1', repeat('0', 64)));
insert into api042_comms_results values('announce-school-denied', private.api042_command(
  'createAnnouncement', :'school_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'title', 'Rogue school-wide notice', 'body', 'x')),
  ((select result->>'id' from api042_comms_results where name = 'announce-school-denied-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_comms_results where name = 'announce-school-denied'), 'forbidden',
  'a teacher cannot create a school-wide announcement');

select set_config('studafy.request_id', 'api042-announce-classroom', true);
insert into api042_comms_results values('announce-classroom-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.createAnnouncement', 'api042-announce-classroom-1', repeat('1', 64)));
insert into api042_comms_results values('announce-classroom', private.api042_command(
  'createAnnouncement', :'classroom_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'classroomId', :'classroom_id', 'title', 'Field trip', 'body', 'Bring a permission slip.',
    'audience', 'guardians', 'important', true)),
  ((select result->>'id' from api042_comms_results where name = 'announce-classroom-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_comms_results where name = 'announce-classroom'), 'ok',
  'the classroom''s lead teacher creates a classroom announcement');
select (result->'response'->>'id')::uuid as classroom_announcement_id from api042_comms_results where name = 'announce-classroom' \gset

select set_config('request.jwt.claim.sub', :'admin_user', true);
select set_config('studafy.request_id', 'api042-announce-school', true);
insert into api042_comms_results values('announce-school-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.createAnnouncement', 'api042-announce-school-1', repeat('2', 64)));
insert into api042_comms_results values('announce-school', private.api042_command(
  'createAnnouncement', :'school_id', jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'title', 'Term dates', 'body', 'See the calendar.')),
  ((select result->>'id' from api042_comms_results where name = 'announce-school-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_comms_results where name = 'announce-school'), 'ok',
  'a school admin creates a school-wide announcement');
select (result->'response'->>'id')::uuid as school_announcement_id from api042_comms_results where name = 'announce-school' \gset

select set_config('request.jwt.claim.sub', :'guardian_user', true);
select ok(
  (private.api042_query('listAnnouncements', null, jsonb_build_object('schoolId', :'school_id'))->'items')::text
    like '%' || :'school_announcement_id' || '%',
  'a member sees the school-wide announcement'
);
select ok(
  (private.api042_query('listAnnouncements', null, jsonb_build_object('schoolId', :'school_id'))->'items')::text
    like '%' || :'classroom_announcement_id' || '%',
  'a verified guardian of an enrolled student sees the classroom announcement'
);

select set_config('request.jwt.claim.sub', :'other_school_user', true);
select is(
  private.api042_query('listAnnouncements', null, jsonb_build_object('schoolId', :'school_id'))->>'outcome',
  'forbidden', 'a different school''s member cannot list this school''s announcements'
);

-- --------------------------------------------------------------------------
-- Transactional integrity: forced audit failure rolls back the whole
-- command, same guarantee proven for S1/S2/S3.
-- --------------------------------------------------------------------------

create function pg_temp.reject_api042_comms_audit() returns trigger language plpgsql as $$
begin
  if new.request_id = 'api042-comms-force-audit' then raise exception 'API042_COMMS_FORCED_AUDIT'; end if;
  return new;
end $$;
create trigger api042_comms_force_audit before insert on public.audit_events
for each row execute function pg_temp.reject_api042_comms_audit();
select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.request_id', 'api042-comms-force-audit', true);
insert into api042_comms_results values('audit-reservation', private.api_idempotency_reserve(
  :'school_id', 'v1.sendMessage', 'api042-comms-audit-key-1', repeat('3', 64)));
create function pg_temp.api042_comms_audit_failure(p_conversation_id uuid, p_reservation_id uuid)
returns jsonb language sql as $$
  select private.api042_command('sendMessage', p_conversation_id,
    jsonb_build_object('responseStatus', 201, 'body', jsonb_build_object(
      'clientMessageId', gen_random_uuid(), 'body', 'This must roll back')),
    p_reservation_id, 1)
$$;
select throws_ok(
  format(
    'select pg_temp.api042_comms_audit_failure(%L::uuid, %L::uuid)',
    :'conversation_id',
    (select result->>'id' from api042_comms_results where name = 'audit-reservation')
  ),
  'API042_COMMS_FORCED_AUDIT', 'forced audit failure escapes the command'
);
select is((select count(*) from public.messages where conversation_id = :'conversation_id'), 1::bigint,
  'the forced-failure message never committed; the conversation still has exactly one message');
drop trigger api042_comms_force_audit on public.audit_events;

select * from finish();
rollback;

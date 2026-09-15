begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select plan(16);

select ok(
  has_function_privilege('studafy_api_runtime', 'private.api042_command(text,uuid,jsonb,uuid,bigint)', 'execute')
  and has_function_privilege('studafy_api_runtime', 'private.api042_query(text,uuid,jsonb)', 'execute'),
  'runtime can execute the notifications query and command entry points'
);
select ok(
  has_function_privilege('studafy_worker_runtime', 'private.notify_recipient(uuid,uuid,text,jsonb,text,text)', 'execute')
  and not has_function_privilege('studafy_api_runtime', 'private.notify_recipient(uuid,uuid,text,jsonb,text,text)', 'execute'),
  'only the worker role can create an arbitrary notification; the ordinary API role never can'
);

-- Simulate three notification-producing events for the teacher and one for
-- the student, the way a future command or OPS-061 worker would.
select private.notify_recipient(:'school_id', :'teacher_user', 'academic.grade_published', '{"assessmentId":"x"}'::jsonb, 'evt-1', 'notify-teacher-1');
select private.notify_recipient(:'school_id', :'teacher_user', 'family.guardian_link_requested', '{"studentId":"y"}'::jsonb, 'evt-2', 'notify-teacher-2');
select private.notify_recipient(:'school_id', :'teacher_user', 'communications.message_sent', '{"conversationId":"z"}'::jsonb, 'evt-3', 'notify-teacher-3');
select private.notify_recipient(:'school_id', :'student_user', 'academic.assignment_published', '{"assignmentId":"a"}'::jsonb, 'evt-4', 'notify-student-1');

-- A repeated call with the same idempotency key must not create a second
-- outbox/delivery row.
select private.notify_recipient(:'school_id', :'teacher_user', 'academic.grade_published', '{"assessmentId":"x"}'::jsonb, 'evt-1', 'notify-teacher-1');
select is(
  (select count(*) from public.notification_outbox where school_id = :'school_id' and idempotency_key = 'notify-teacher-1'),
  1::bigint, 'notify_recipient is idempotent on (school_id, idempotency_key)'
);
select is(
  (select count(*) from public.notification_deliveries nd join public.notification_outbox o on o.id = nd.outbox_id
   where o.idempotency_key = 'notify-teacher-1'),
  1::bigint, 'the matching delivery row is not duplicated either'
);

-- --------------------------------------------------------------------------
-- listNotifications / getUnreadCount
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.school_id', '', true);
select is(
  jsonb_array_length(private.api042_query('listNotifications', null, '{}'::jsonb)->'items'),
  3, 'the teacher sees exactly their own three notifications'
);
select is(
  (private.api042_query('getUnreadCount', null, '{}'::jsonb)->>'unreadCount')::int,
  3, 'all three start unread'
);

select set_config('request.jwt.claim.sub', :'student_user', true);
select is(
  jsonb_array_length(private.api042_query('listNotifications', null, '{}'::jsonb)->'items'),
  1, 'the student sees only their own one notification, not the teacher''s'
);

-- --------------------------------------------------------------------------
-- markNotificationsRead
-- --------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', :'teacher_user', true);
select set_config('studafy.request_id', 'api042-mark-read-invalid', true);
create temporary table api042_notif_results(name text primary key, result jsonb);
insert into api042_notif_results values('mark-too-many-reservation', private.api_idempotency_reserve(
  null, 'v1.markNotificationsRead', 'api042-mark-too-many-1', repeat('a', 64)));
insert into api042_notif_results values('mark-too-many', private.api042_command(
  'markNotificationsRead', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'ids', (select jsonb_agg(g) from generate_series(1, 101) g))),
  ((select result->>'id' from api042_notif_results where name = 'mark-too-many-reservation')::uuid), 1));
select is((select result->>'outcome' from api042_notif_results where name = 'mark-too-many'), 'invalid',
  'marking more than 100 ids at once is rejected');

select set_config('studafy.request_id', 'api042-mark-read-all', true);
insert into api042_notif_results values('mark-all-reservation', private.api_idempotency_reserve(
  null, 'v1.markNotificationsRead', 'api042-mark-all-key-1', repeat('b', 64)));
insert into api042_notif_results values('mark-all', private.api042_command(
  'markNotificationsRead', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('all', true)),
  ((select result->>'id' from api042_notif_results where name = 'mark-all-reservation')::uuid), 1));
select is((select result->'response'->>'markedCount' from api042_notif_results where name = 'mark-all'), '3',
  'marking all as read reports exactly the three notifications it touched');
select is(
  (private.api042_query('getUnreadCount', null, '{}'::jsonb)->>'unreadCount')::int,
  0, 'the unread count drops to zero after marking all read'
);

select set_config('studafy.request_id', 'api042-mark-read-again', true);
insert into api042_notif_results values('mark-again-reservation', private.api_idempotency_reserve(
  null, 'v1.markNotificationsRead', 'api042-mark-again-key-1', repeat('c', 64)));
insert into api042_notif_results values('mark-again', private.api042_command(
  'markNotificationsRead', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object('all', true)),
  ((select result->>'id' from api042_notif_results where name = 'mark-again-reservation')::uuid), 1));
select is((select result->'response'->>'markedCount' from api042_notif_results where name = 'mark-again'), '0',
  'marking as read again touches nothing further, not an error');

-- --------------------------------------------------------------------------
-- notification preferences
-- --------------------------------------------------------------------------

select set_config('studafy.request_id', 'api042-set-global-pref', true);
insert into api042_notif_results values('pref-global-reservation', private.api_idempotency_reserve(
  null, 'v1.updateNotificationPreferences', 'api042-pref-global-1', repeat('d', 64)));
insert into api042_notif_results values('pref-global', private.api042_command(
  'updateNotificationPreferences', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'channel', 'email', 'category', 'academic', 'enabled', false)),
  ((select result->>'id' from api042_notif_results where name = 'pref-global-reservation')::uuid), 1));
select is((select result->'response'->>'enabled' from api042_notif_results where name = 'pref-global'), 'false',
  'a global (no schoolId) preference is created disabled as requested');

select set_config('studafy.request_id', 'api042-set-school-pref', true);
insert into api042_notif_results values('pref-school-reservation', private.api_idempotency_reserve(
  null, 'v1.updateNotificationPreferences', 'api042-pref-school-1', repeat('e', 64)));
insert into api042_notif_results values('pref-school', private.api042_command(
  'updateNotificationPreferences', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'schoolId', :'school_id', 'channel', 'push', 'category', 'meetings', 'enabled', true)),
  ((select result->>'id' from api042_notif_results where name = 'pref-school-reservation')::uuid), 1));
select is((select result->'response'->>'schoolId' from api042_notif_results where name = 'pref-school'), :'school_id'::text,
  'a per-school preference records its schoolId');

select is(
  jsonb_array_length(private.api042_query('getNotificationPreferences', null, '{}'::jsonb)->'items'),
  2, 'both the global and per-school preference are listed'
);

-- Re-setting the same global preference upserts rather than duplicating.
select set_config('studafy.request_id', 'api042-set-global-pref-again', true);
insert into api042_notif_results values('pref-global-again-reservation', private.api_idempotency_reserve(
  null, 'v1.updateNotificationPreferences', 'api042-pref-global-again-1', repeat('f', 64)));
insert into api042_notif_results values('pref-global-again', private.api042_command(
  'updateNotificationPreferences', null, jsonb_build_object('responseStatus', 200, 'body', jsonb_build_object(
    'channel', 'email', 'category', 'academic', 'enabled', true)),
  ((select result->>'id' from api042_notif_results where name = 'pref-global-again-reservation')::uuid), 1));
select is((select result->'response'->>'enabled' from api042_notif_results where name = 'pref-global-again'), 'true',
  'the same (channel, category) global preference upserts in place');
select is(
  jsonb_array_length(private.api042_query('getNotificationPreferences', null, '{}'::jsonb)->'items'),
  2, 'the upsert did not create a third preference row'
);

select * from finish();
rollback;

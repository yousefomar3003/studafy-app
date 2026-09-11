-- DB-020 measured index candidates. Every index corresponds to a query in
-- docs/database/db020-index-catalogue.md and is exercised by plan tests.

create index db020_memberships_user_active
on public.memberships (user_id, school_id, role)
where active;

create index db020_memberships_school_role_active
on public.memberships (school_id, role, user_id)
where active;

create index db020_guardian_links_guardian_verified
on public.guardian_links (guardian_id, school_id, student_id)
where status = 'verified';

create index db020_guardian_links_student_verified
on public.guardian_links (student_id, guardian_id)
where status = 'verified';

create index db020_enrollments_student_active
on public.enrollments (student_id, school_id, classroom_id)
where active;

create index db020_enrollments_classroom_active
on public.enrollments (classroom_id, student_id)
where active;

create index db020_classroom_staff_user_active
on public.classroom_staff (user_id, school_id, classroom_id)
where status = 'active';

create index db020_classroom_staff_classroom_active
on public.classroom_staff (classroom_id, user_id, role)
where status = 'active';

create index db020_classrooms_school_term_active
on public.classrooms (school_id, term_id, id)
where status = 'active';

create index db020_class_schedules_classroom_effective
on public.class_schedules (classroom_id, effective_from, effective_until);

create index db020_resource_publications_class_published
on public.resource_publications (classroom_id, published_at desc, id desc)
where state = 'published' and withdrawn_at is null;

create index db020_resource_publications_school_published
on public.resource_publications (school_id, published_at desc, id desc)
where state = 'published' and withdrawn_at is null;

create index db020_assignments_class_due
on public.assignments (classroom_id, due_at, id)
where state = 'published' and deleted_at is null;

create index db020_submissions_student_status
on public.submissions (student_id, status, updated_at desc, id desc);

create index db020_submissions_assignment_status
on public.submissions (assignment_id, status, updated_at desc, id desc);

create index db020_grade_results_student_published
on public.grade_results (student_id, published_at desc, id desc)
where state = 'published';

create index db020_grade_results_assessment_state
on public.grade_results (assessment_id, state, id);

create index db020_attendance_student_timeline
on public.attendance_records (student_id, recorded_at desc, id desc);

create index db020_attendance_session_state
on public.attendance_records (session_id, state, student_id);

create index db020_notifications_user_unread
on public.notifications (user_id, created_at desc, id desc)
where read_at is null;

create index db020_notification_outbox_ready
on public.notification_outbox (next_attempt_at, id)
where state in ('pending', 'retry');

create index db020_store_events_ready
on public.store_events (next_attempt_at, id)
where state in ('pending', 'retry');

create index db020_file_objects_clean_dedupe
on public.file_objects (school_id, sha256, size_bytes)
where scan_state = 'clean' and deleted_at is null;

create index db020_upload_sessions_expiry
on public.upload_sessions (expires_at, id)
where state in ('initiated', 'uploaded');

create index db020_idempotency_expiry
on public.idempotency_records (expires_at, id);

create index db020_conversation_participants_user_active
on public.conversation_participants (user_id, conversation_id)
where left_at is null;

create index db020_messages_conversation_cursor
on public.messages (conversation_id, created_at desc, id desc);

create index db020_membership_events_membership_time
on public.membership_events (membership_id, created_at desc, id desc);

create index db020_membership_events_school_time
on public.membership_events (school_id, created_at desc, id desc);

create index db020_grade_result_events_result_time
on public.grade_result_events (grade_result_id, created_at desc, id desc);

create index db020_audit_events_school_time
on public.audit_events (school_id, created_at desc, id desc);

create index db020_store_transactions_original
on public.store_transactions (platform, environment, original_transaction_id, purchased_at desc);

create index db020_store_transactions_purchaser_time
on public.store_transactions (purchaser_id, purchased_at desc, id desc);

create index db020_entitlements_user_status
on public.entitlements (user_id, status, feature_key);

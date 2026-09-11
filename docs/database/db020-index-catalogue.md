# DB-020 index catalogue

Indexes below are implemented by `202609110006_db020_indexes.sql`. “Plan” is
the intended bounded access path. Rows marked **measured** are exercised against
the deterministic local scale fixture; the remaining paths are schema-backed
candidates that must be measured with representative data before remote use.
Cardinality is the expected result bound, not a production claim. Write cost is
relative to the indexed relation.

| Index | Query and plan | Cardinality | Write cost | Justification |
|---|---|---:|---|---|
| `db020_memberships_user_active` | active roles by user; partial index scan (**measured**) | roles × schools, bounded | Low | auth context resolution |
| `db020_memberships_school_role_active` | active users by school/role; partial index range | paged | Medium | admin and recipient expansion |
| `db020_guardian_links_guardian_verified` | verified students by guardian; partial index scan (**measured**) | paged | Low | guardian authorization/list |
| `db020_guardian_links_student_verified` | verified guardians by student; partial index range | small/paged | Low | reverse family lookup |
| `db020_enrollments_student_active` | active classrooms by student; partial index scan (**measured**) | small | Medium | authorization and student home |
| `db020_enrollments_classroom_active` | active roster by classroom; partial index range | paged | Medium | rosters and fan-out |
| `db020_classroom_staff_user_active` | active classrooms by staff user; partial index scan (**measured**) | paged | Low | staff authorization |
| `db020_classroom_staff_classroom_active` | active staff by classroom/role; partial range | small | Low | co-teaching roster |
| `db020_classrooms_school_term_active` | active classrooms for tenant/term; partial ordered scan (**measured**) | paged | Low | classroom feed |
| `db020_class_schedules_classroom_effective` | schedule by classroom/effective range; index range | small | Low | timetable rendering |
| `db020_resource_publications_class_published` | published class feed cursor; partial ordered scan | paged | Medium | class resource feed |
| `db020_resource_publications_school_published` | published school feed cursor; partial ordered scan | paged | Medium | school resource feed |
| `db020_assignments_class_due` | open published assignments by class/due date; partial range | paged | Medium | assignment dashboard |
| `db020_submissions_student_status` | student submissions by state/update cursor; ordered range | paged | Medium | student work history |
| `db020_submissions_assignment_status` | assignment submissions by state/update cursor; ordered range | paged | Medium | teacher marking queue |
| `db020_grade_results_student_published` | published grade history cursor; partial ordered scan (**measured**) | paged | Medium | student/guardian grade feed |
| `db020_grade_results_assessment_state` | results by assessment/state; index range | paged | Medium | grading workflow |
| `db020_attendance_student_timeline` | attendance timeline cursor; ordered index scan (**measured**) | paged | Medium | student/guardian timeline |
| `db020_attendance_session_state` | session roster/state; index range | paged | Medium | teacher attendance view |
| `db020_notifications_user_unread` | unread notification cursor; partial ordered scan (**measured**) | paged | Medium | inbox badge/feed |
| `db020_notification_outbox_ready` | due pending/retry work; partial ordered scan (**measured**) | worker batch | Medium | lockable worker polling |
| `db020_store_events_ready` | due store webhook work; partial ordered scan | worker batch | Medium | billing reconciliation |
| `db020_file_objects_clean_dedupe` | exact clean tenant hash/size; partial index scan (**measured**) | 0–few | High | safe object deduplication |
| `db020_upload_sessions_expiry` | expired initiated/uploaded sessions; partial ordered scan | worker batch | Medium | quarantine cleanup |
| `db020_idempotency_expiry` | expired idempotency rows; ordered range | worker batch | Medium | bounded operational storage |
| `db020_conversation_participants_user_active` | active conversations by user; partial range | paged | Medium | conversation inbox |
| `db020_messages_conversation_cursor` | messages by conversation cursor; ordered range | paged | Medium | message history |
| `db020_membership_events_membership_time` | membership history cursor; ordered range | paged | Medium | identity audit |
| `db020_membership_events_school_time` | tenant membership event cursor; ordered range | paged | Medium | admin audit |
| `db020_grade_result_events_result_time` | grade state history cursor; ordered range | paged | Medium | grade audit/review |
| `db020_audit_events_school_time` | tenant audit cursor; ordered index scan (**measured**) | paged | High | incident/admin review |
| `db020_store_transactions_original` | original purchase history; ordered range | small/paged | Medium | restore/reconciliation |
| `db020_store_transactions_purchaser_time` | purchaser transaction cursor; ordered range | paged | Medium | account purchase history |
| `db020_entitlements_user_status` | user feature/status lookup; index scan | small | Medium | authorization-ready entitlement lookup |

The local fixture has 2,000 students, 2,000 classrooms, 6,000 staff rows,
2,000 guardian links, 2,000 enrollments, 2,000 grades, 10,000 notifications,
5,000 files, 5,000 outbox rows, and 5,000 audit events. Its eleven hot-query
plans reject a sequential scan on the populated target relation and require a
median below 50 ms and worst run below 150 ms over three executions. Local
latencies are regression indicators only, not production SLOs.

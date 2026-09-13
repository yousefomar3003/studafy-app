# DB-021 direct-access policy matrix

Every row also requires an active profile. School-owned access requires an
active school and an active, in-window membership. `parent` is accepted only as
a temporary alias for `guardian` until Phase 3.

| Relation group | School admin | Assigned class staff | Student | Guardian/parent | Anonymous | Direct writes |
|---|---|---|---|---|---|---|
| Profile / memberships | Self | Self | Self | Self | Deny | Deny |
| Schools / terms | Member; all term states | Member; all term states | Active term | Active term | Deny | Deny |
| Classrooms / schedules | Same school | Exact assignment | Exact active enrollment | Verified linked child enrollment | Deny | Deny |
| Students / enrollments | Same school | Exact staffed classroom | Self row only | Linked child row only | Deny | Deny |
| Guardian links | Same school | Exact staffed classroom | Own student identity | Own links | Deny | Deny |
| Sessions / materials | Same school | Exact class, all states | Completed/filed class content | Completed/filed linked-class content | Deny | Deny |
| Assignments / assessments | Same school | Exact class, all states | Published exact class | Published linked class | Deny | Deny |
| Assessment questions | Same school | Exact class | Published practice only; no answer key | Published practice only; no answer key | Deny | Deny |
| Submissions / grades / attendance | Same school | Exact class/student | Own; grades published only | Linked child; grades published only | Deny | Deny |
| Wellbeing `class_staff` | Allow | Exact class | Deny | Deny | Deny | Deny |
| Wellbeing `guardian_shared` | Allow | Exact class | Deny | Verified guardian | Deny | Deny |
| Wellbeing `student_guardian_shared` | Allow | Exact class | Own student | Verified guardian | Deny | Deny |
| Wellbeing `safeguarding_restricted` | Allow | Creator only | Deny | Deny | Deny | Deny |
| Announcements / meetings | Same school | Exact class/creator | Matching published audience | Matching published audience | Deny | Deny |
| Meeting deliveries | Same school | Exact class | Recipient | Recipient | Deny | Deny |
| Notifications / legacy entitlements / consent | Own rows | Own rows | Own rows | Own rows | Deny | RPC only where defined |
| Practice sessions | Same school | Exact class | Own exact enrollment | Deny | Deny | Deny |
| Resources / versions / publications | Same school | Active school teacher | Clean published audience | Clean published audience | Deny | Deny |
| Files, upload sessions, AI, audit/events, outbox/deliveries, new billing, idempotency, conversations/messages | Deny | Deny | Deny | Deny | Deny | Service-only and unactivated |

Negative coverage is executable in `supabase/tests/db021_access.sql` and
`supabase/tests/db021_grants.sql`. The matrix intentionally does not grant a
school-wide teacher role: teachers require `classroom_staff` for student data.

# DB-021 policy index catalogue

These indexes fill policy/feed gaps not already covered by DB-020. The local
scale verifier rejects sequential scans on populated target relations and
enforces provisional median/worst execution bounds of 50/150 ms. These are
regression thresholds, not production SLOs.

| Index | Query / policy path | Expected result | Write cost | Reason |
|---|---|---:|---|---|
| `db021_lesson_materials_session_visible` | visible materials by filed session | Paged | Medium | Session authorization and Study Coach grounding |
| `db021_assessments_class_published` | published class assessment cursor | Paged | Medium | Student/guardian assessment feed |
| `db021_wellbeing_student_timeline` | authorized student wellbeing timeline | Paged | Medium | Visibility-filtered wellbeing history |
| `db021_announcements_school_feed` | published tenant announcement cursor | Paged | Medium | Audience-filtered school feed |
| `db021_meetings_class_time` | scheduled classroom meetings by time | Paged | Medium | Audience-filtered meeting feed |
| `db021_resource_publications_version_state` | publication lookup from resource version | Few | Medium | Clean/publication authorization helper |

DB-021 additionally relies on DB-020 membership, guardian-link, enrollment,
classroom-staff, classroom, grade, attendance, notification, and resource
publication indexes. The deterministic DB-021 fixture contains three schools,
1,200 students/enrollments/grades, 120 classrooms, and 6,000 notifications.

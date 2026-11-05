# Studafy School Portal: plan and build instructions

> **Status: planned, not started (written 2026-11-05).**
> This document lives only on the long-lived branch `feat/school-admin-web`.
> **Nothing on this branch is merged into `main` until every gate in
> [section 11](#11-the-release-gate-when-this-may-be-merged) is met.** The
> version of Studafy in store review has no school administrator, and must
> not gain one by accident.

---

## Contents

1. [What we are building, in one page](#1-what-we-are-building-in-one-page)
2. [Who uses it and what each person can do](#2-who-uses-it-and-what-each-person-can-do)
3. [Version 1 scope (and what is deliberately left out)](#3-version-1-scope-and-what-is-deliberately-left-out)
4. [The website's public pages](#4-the-websites-public-pages)
5. [Screens of the portal](#5-screens-of-the-portal)
6. [The teacher's side, in the phone app](#6-the-teachers-side-in-the-phone-app)
7. [How it is built: architecture](#7-how-it-is-built-architecture)
8. [Build instructions, step by step](#8-build-instructions-step-by-step)
9. [Privacy, legal and safety](#9-privacy-legal-and-safety)
10. [Testing](#10-testing)
11. [The release gate: when this may be merged](#11-the-release-gate-when-this-may-be-merged)
12. [How to keep the branch separate from `main`](#12-how-to-keep-the-branch-separate-from-main)
13. [Later versions](#13-later-versions)
14. [Open questions for the owner](#14-open-questions-for-the-owner)

---

## 1. What we are building, in one page

**Studafy School Portal** is a website, at `https://school.studafy.com`, for
a school's principal or administrator. It is not part of the phone app.

In version 1 the administrator can do two things:

1. **Link teachers to the school.** The administrator gets a *school code*.
   A teacher types it into the Studafy app, sees which school is asking,
   and **approves or declines**. It works the same way a parent links to a
   student today: one side asks, the other side approves. The teacher can
   unlink at any time.
2. **See the classes of linked teachers, read-only.** Classes, students,
   assignments, online tests, published marks and attendance. The
   administrator **cannot change anything**, cannot message anyone, and
   never sees private messages, AI tutor chats, notebooks or draft marks.

Everything teachers do today stays exactly the same. A teacher who never
links to a school notices nothing.

**Why a website:** principals work at a computer; tables of classes and
marks read better on a wide screen; a website needs no App Store or Google
Play review and updates instantly; and it can later be sold to schools
directly, by invoice, without store fees.

**Why so small:** a small first version can be built, reviewed and made
safe quickly, and shows schools the value before the bigger features
(one code for all classes, announcements, messaging) are added
([section 13](#13-later-versions)).

---

## 2. Who uses it and what each person can do

| Person | Where | What they can do in version 1 |
|---|---|---|
| **School administrator** (principal, head of school, school IT) | Website | Create the school's page; get the school code; see linked teachers; see those teachers' shared classes, read-only; unlink a teacher; add or remove a second administrator (optional, see 14). |
| **Teacher** | Phone app | Enter a school code; see the school's name and who asked; approve or decline; choose **all classes** or **only some classes** to share; stop sharing a class; unlink from the school. |
| **Student** | Phone app | Nothing to do. Sees a short notice when a class they are in is shared with a school ([9.4](#94-telling-students-and-parents)). |
| **Parent** | Phone app | Nothing to do. Sees the same notice for their child's class. |
| **Studafy (platform operator)** | Existing operator tools | Approves each new school before it can send codes ([9.5](#95-stopping-fake-schools)); can suspend a school. |

The administrator is **not** a new role in the phone app. An administrator
signs in to the website with an Apple, Google or Microsoft (Outlook,
Hotmail, Microsoft 365) account. If the same
person is also a teacher, they keep their teacher account in the app; the
two do not mix.

---

## 3. Version 1 scope (and what is deliberately left out)

### In version 1

- Public website (section 4): the landing page, a page about the Studafy
  app, a "Who we are" page and a contact page.
- Sign in with Apple, Google or Microsoft (Outlook, Hotmail, Microsoft
  365) on the website.
- Create a school: name, country, city, type (public/private), the
  administrator's job title, a contact phone. It waits for Studafy's
  approval before its code works.
- The school code: shown on the dashboard, can be copied, can be replaced
  ("Make a new code"; the old one stops working at once).
- Linked teachers list, with status: *Waiting for the teacher*, *Linked*,
  *Declined*, *Unlinked*.
- Per teacher: the classes they shared.
- Per class, read-only tabs:
  - **Students:** names only (no email, no phone, no photo).
  - **Assignments:** title, due date, how many handed in, how many marked.
  - **Online tests:** title, date, how many sat it, average of published
    marks.
  - **Marks:** a table of students × published items. Only published
    marks; never drafts, never AI-suggested marks.
  - **Attendance:** totals per student (present, absent, late) and per
    lesson day.
- Unlink a teacher (from the administrator's side).
- English and Arabic, with right-to-left layout for Arabic.
- An activity record: every page the administrator opens is written to
  the audit log (who, which class, when).

### Deliberately not in version 1

- No editing of anything: classes, marks, students, attendance.
- No messages, announcements or notifications from the school.
- No view of: messages, AI tutor chats, notebooks, flashcards, uploaded
  files' contents, hand-in files, draft marks, AI marking suggestions,
  parents' details, students' contact details.
- No one code that puts students into many classes (version 2).
- No billing. Version 1 is free for pilot schools.
- No school administrator inside the phone app.
- No exporting to Excel/PDF (version 2, once the data-protection agreement
  covers it).

---

## 4. The website's public pages

The public pages are what someone sees at `https://school.studafy.com`
before signing in. They say who Studafy is, what the Studafy app does, and
plainly what the portal does and does **not** do, because principals,
teachers and parents will all read them. English and Arabic; the language
follows the browser, with a switch in the header.

### 4.1 The pages

| Address | Page | Section |
|---|---|---|
| `/` | Landing page (for schools) | [4.2](#42-landing-page-sections-top-to-bottom) |
| `/app` | The Studafy app: everything it does | [4.3](#43-the-studafy-app-page-app) |
| `/about` | Who we are | [4.4](#44-who-we-are-page-about) |
| `/contact` | Contact | [4.5](#45-contact-page-contact) |
| `/signin` | Sign in (Apple, Google, Microsoft) | [5.1](#51-sign-in) |
| Privacy, Terms | Links to `https://legal.studafy.com/privacy` and `/terms` (never copies) | |

Every public page has the same header and footer:

- **Header:** Studafy logo (goes to `/`) · **The app** · **For schools** ·
  **Who we are** · **Contact** · language switch (English / العربية) ·
  **Sign in** button. On a phone the links fold into a menu button.
- **Footer:** © Studafy Limited · The app · For schools · Who we are ·
  Contact · Privacy · Terms · App Store and Google Play badges · language
  switch.

### 4.2 Landing page sections, top to bottom

1. **Header** (as above).
2. **Hero:**
   - Heading: **"See your school's classes in one place."**
   - Text: "Studafy School Portal lets a principal see the classes,
     homework, tests, marks and attendance of the teachers who choose to
     share them with the school. Teachers stay in control."
   - Buttons: **Create your school's page** (primary, goes to sign-in) ·
     **How it works** (scrolls down).
   - Image: a clean screenshot of the dashboard with invented data.
3. **What is Studafy:** a short band about the app the portal is built on.
   - Heading: **"Studafy: one app for a class's everyday work."**
   - Text: "Teachers, students and parents use Studafy for lessons,
     homework, online and paper tests, marks, attendance and messages, in
     English or Arabic. The School Portal adds a view for the school."
   - Three small cards: **For teachers** · **For students** · **For
     parents**, each with two lines taken from [4.3](#43-the-studafy-app-page-app).
   - Link: **See everything the app does** (goes to `/app`).
4. **How it works, in three steps:**
   1. "**Create your school's page.** Sign in with Apple, Google or
      Microsoft. We check every school before it goes live."
   2. "**Share your school code with your teachers.** Each teacher enters
      it in the Studafy app and chooses which classes to share."
   3. "**See everything in one place.** Classes, homework, tests, marks
      and attendance, always up to date."
5. **What you can see:** five cards with icons: Classes and students ·
   Homework · Online tests · Marks · Attendance.
6. **Teachers stay in control:** "Nothing is shared until a teacher
   approves. A teacher can stop sharing a class, or leave the school, at
   any time. The portal is read-only: it cannot change marks or classes."
7. **Privacy, in plain words:**
   - "Only what teachers share. Only read-only."
   - "Private messages, AI tutor chats and students' notes are never
     shown to the school."
   - "Students and parents are told when a class is shared with a
     school."
   - "Every page a school administrator opens is recorded."
   - Link: "Read the Privacy Policy" (`https://legal.studafy.com/privacy`).
8. **For teachers:** "Already teaching on Studafy? Nothing changes for you
   unless you choose to link with your school." Link to the app on the
   App Store and Google Play.
9. **Who we are (short):** two or three sentences from
   [4.4](#44-who-we-are-page-about) and a link **More about us** (goes to
   `/about`).
10. **Questions (FAQ):**
   - *Does it cost anything?* "The portal is free for schools during the
     pilot."
   - *Can the school change marks?* "No. The portal is read-only."
   - *Can the school read messages?* "No."
   - *What if a teacher leaves the school?* "They unlink in the app, and
     the school stops seeing their classes at once."
   - *Who can create a school page?* "A principal or someone they
     authorise. We check every school before it goes live."
   - *Which accounts can I sign in with?* "Apple, Google or Microsoft
     (including Outlook, Hotmail and Microsoft 365 school accounts)."
   - *Do students need to do anything?* "No. Students and parents keep
     using the Studafy app as they do now."
11. **Footer** (as above).

### 4.3 The Studafy app page (`/app`)

What the whole app does, for someone who has never used it. The text comes
from the store listing (`docs/store/listing-copy.md` on `main`), so the
website never promises more than the app does. Re-read that file when
writing this page, and again before the release gate: anything added to or
removed from the listing is added to or removed from this page.

1. **Top:** heading **"Studafy: lessons, homework, tests, marks and
   attendance in one app."** Text: "For teachers, students and parents.
   In English and Arabic. No ads, and we never sell your data." App
   Store and Google Play badges. Three phone screenshots (teacher,
   student, parent) with invented data, the same pictures as the store
   listing.
2. **For teachers:**
   - Create classes, set the timetable, invite students with a class code
     or link.
   - Share lessons with notes, files (PDF, Word, PowerPoint, images) and
     links.
   - Set homework with a due date, see who handed in, give extra time.
   - Online exams: single-answer, multiple-answer, true or false,
     short-answer and essay questions. Questions with a set answer are
     marked automatically; the teacher marks the rest and chooses when
     students see the correct answers.
   - One gradebook for paper tests and online work. Marks stay private
     until the teacher publishes them; a corrected mark keeps a record of
     the change and the reason.
   - Attendance (present, absent, late, excused), wellbeing notes,
     announcements and messages to students and parents.
   - **Studafy AI Marking** (optional monthly subscription for teachers):
     AI suggests marks for written answers and hand-ins against the
     teacher's own model answer, and **the teacher decides every mark**.
3. **For students:**
   - Join a class with a code, or start on your own and join one later.
   - Read lessons by date, keep your own notes, hand in homework as typed
     answers, photos or documents, take online exams on the phone.
   - See published marks, feedback and attendance; message teachers.
   - **AI Tutor** about your lessons and your own notes, in a class or on
     your own. **Studafy Plus** adds photos in questions, study notes made
     from a lesson or a photo, and notebooks with highlights and
     bookmarks. **Studafy Max** adds quizzes and flashcards made from your
     lessons and notes. Text under it: "The AI Tutor's answers can be
     wrong, so check them. Email addresses and marks are never sent to
     the AI service, and names are replaced first."
4. **For parents:**
   - Link to your child with their Studafy ID; the child approves on
     their own device.
   - Follow published marks, homework and attendance; read announcements;
     message teachers.
   - Create an account for a younger child who has no email address, and
     switch between accounts on one phone.
   - **Family+** (optional monthly subscription): what to focus on this
     week, marks over time, each class at a glance, missing work and
     missed tests.
5. **For schools:** one paragraph about the School Portal and a link to
   `/`.
6. **Privacy and safety:** no ads; data never sold; marks shown only after
   the teacher publishes; report or block anyone in a conversation;
   download your data or delete your account inside the app; sign in with
   Apple, Google or Microsoft.
7. **English and Arabic:** the whole app, with right-to-left layout in
   Arabic.
8. **Free and paid:** "Lessons, homework, marks and attendance are free.
   Studafy Plus, Studafy Max, Family+ and Studafy AI Marking are optional
   monthly subscriptions, bought in the app." **No prices on the
   website:** they differ by country and are shown by the App Store and
   Google Play.
9. **Get the app:** App Store and Google Play badges again.

### 4.4 Who we are page (`/about`)

Facts about the company come only from the owner. Every `[OWNER: …]` below
is filled in by the owner before the page goes live; the build never
invents names, dates, places or numbers.

1. **Heading:** "Who we are".
2. **Our mission:** "We make the everyday work of a class simpler for
   teachers, clearer for students and easier to follow for parents, in
   English and Arabic." (The owner may rewrite it.)
3. **Our story:** [OWNER: why Studafy was started, by whom, when and
   where; two or three short paragraphs].
4. **What we believe** (four short cards, each a promise the app already
   keeps):
   - **Teachers decide.** Marks are private until a teacher publishes
     them, and AI only suggests; the teacher decides.
   - **Privacy first.** No ads, we never sell data, and the school sees
     only what a teacher shares.
   - **Built for English and Arabic.** Written, not machine-translated,
     with a real right-to-left layout.
   - **Free where it matters.** Lessons, homework, marks and attendance
     are free.
5. **The team:** [OWNER: names, roles and, only if wanted, photos. Can be
   left out entirely; see 14].
6. **The company:** "Studafy is made by Studafy Limited." [OWNER: country
   of registration, company number and registered address if they are to
   be shown; the legal pages already name the data controller].
7. **Get in touch:** link to `/contact`.

### 4.5 Contact page (`/contact`)

- Email `hello@studafy.com` (a `mailto:` link) for questions, schools that
  want to join the pilot, privacy requests and press.
- Ready-made links with a subject line: "School Portal pilot", "Privacy
  request", "Help with the app".
- Text: "We usually answer within two working days."
- **No contact form in version 1:** a form needs storage, spam protection
  and its own privacy text; email is enough to start.
- Links to the Privacy Policy and Terms.

### 4.6 Rules for every public page

- No tracking scripts, no ads, no third-party analytics. The only
  external services are Studafy's own API, Supabase Auth and Cloudflare
  Turnstile (on the create-school form).
- Must work on a phone browser too (single column below 720 px).
- Images use invented people and schools only.
- Claims about the app follow the store listing's rules: only what the
  code does, no "best" or "#1", no competitor names, no prices, nothing
  aimed at children in marketing language.
- App Store and Google Play badges use the official artwork and the
  stores' badge rules, and link to the real store pages.
- The public pages are built to plain HTML at build time (prerendered), so
  they load fast on slow phones and search engines can read them. Each
  page has its own title, description and social-share image.
- Arabic copy is written, not machine-translated, and reviewed like the
  app's Arabic strings (`lib/l10n/app_ar.arb` style: "Studafy", plan and
  product names in Latin letters).

---

## 5. Screens of the portal

All screens after sign-in. Left side menu on a computer; bottom menu on a
phone.

### 5.1 Sign in

- Three buttons, in this order: **Sign in with Apple** · **Continue with
  Google** · **Continue with Microsoft**. Under the Microsoft button, in
  small text: "Outlook, Hotmail or Microsoft 365 school account".
- Each button follows its company's design rules (Apple's black or white
  button with the Apple logo; Google's and Microsoft's official logos).
- Under the buttons: "By continuing you agree to the Terms of Use and
  Privacy Policy."
- **Apple's "Hide My Email":** a person who signs in with Apple can hide
  their email, and Studafy then gets an address ending in
  `@privaterelay.appleid.com`. In that case the create-school form (5.2)
  also asks for a **contact email** at the school, because Studafy's check
  needs a real address.
- **Same person, same button:** signing in with a different button reaches
  the same account only when it carries the same email address (an Apple
  hidden address never matches). The sign-in page says: "Use the same way
  to sign in each time."
- Errors are plain: "Sign-in was cancelled", "That account could not sign
  in. Try another way." Nothing technical is shown.

### 5.2 Create your school (first sign-in only)

Fields: school name · country · city · type (public / private /
international / other) · your job title · a phone number we can call to
verify · a contact email (filled in from the sign-in and editable; required
when the sign-in address is an Apple hidden one) · tick box "I am authorised by this school to create its Studafy
page". Turnstile check. Button **Send for checking**.

After sending: "Thanks. We check every school, usually within two working
days. We will email you at <email>." The dashboard shows *Waiting for
Studafy's check* and no code yet.

### 5.3 Dashboard

- School name and status (*Being checked* / *Active* / *Suspended*).
- **School code** card: the code in large letters (for example
  `CEDAR-7K4M-Q2`), a **Copy** button, **Make a new code**, and the
  sentence "Teachers enter this code in the Studafy app: Account → Link
  to a school."
- Counts: linked teachers, shared classes, students in shared classes.
- "Waiting for the teacher" list (requests not yet answered).

### 5.4 Teachers

Table: name · subjects (from their classes) · status · classes shared ·
linked since · **Unlink** (with a confirmation).

### 5.5 Classes

Table of every shared class: class name · teacher · term · students ·
last activity. Search box and filters (teacher, term).

### 5.6 One class

Header: class name, teacher, term, number of students. Tabs:

| Tab | Shows |
|---|---|
| Overview | Upcoming assignments and tests; average of published marks; attendance rate this month. |
| Students | Names, alphabetical. Nothing else. |
| Assignments | Title · due date · handed in (n of m) · marked (n of m). Opening one shows the same counts and the published marks for it. |
| Online tests | Title · date · sat (n of m) · average published mark. |
| Marks | Grid of students × published items; average per student and per item. |
| Attendance | Per student: present / absent / late totals for the term; per day: counts. |

Every table says when the data was last updated, and shows a clear empty
state ("No published marks yet").

### 5.7 Settings

- School details (name, city; changes go back to Studafy for checking).
- Administrators (only if section 14 decides on more than one).
- **Leave and delete the school's page:** unlinks every teacher and
  removes the school's page.

---

## 6. The teacher's side, in the phone app

This is the only part of the phone app that changes, and it needs a new
app version through store review. It is built on this branch with
everything else and switched off until the release gate.

### 6.1 Link to a school

- **Where:** Account → **Link to a school** (teachers only). Hidden when
  the server says the feature is off (6.4).
- **Steps:**
  1. Enter the school code.
  2. The app shows: school name, city, the administrator's name and job
     title, and "This school will see the classes you choose, read-only.
     It will not see messages, AI tutor chats or students' notes."
  3. Choose **All my classes** (including classes created later) or
     **Choose classes** (a list with ticks).
  4. **Link** / **Cancel**.
- After linking: the screen shows the school, the shared classes, a
  **Change shared classes** button and **Unlink from this school**.

### 6.2 Notices for students and parents

When a class is first shared with a school (and when sharing stops), every
student in that class and their linked parents get an in-app notification:
"*Grade 8 Science* is now shared with *Cedar Grove School*. The school can
see the class's work, marks and attendance. It cannot see messages."
No push sound for this one (a quiet notification).

### 6.3 Strings

New EN/AR strings in `lib/l10n/app_en.arb` and `app_ar.arb`, then
`flutter gen-l10n`. School names are user content: show them through the
existing `user_content_text.dart` helpers (bidi isolation).

### 6.4 The switch

The app shows the entry only when `GET /v1/me` returns
`schoolPortal: true` (a new field the server sets from
`SCHOOL_PORTAL_ENABLED`). Old app versions ignore the field. This lets the
app version with the screen go through review and be released while the
feature stays off, then be switched on from the server.

---

## 7. How it is built: architecture

### 7.1 The pieces

```
school.studafy.com (static website, Vercel)
        │  HTTPS, Bearer token from Supabase Auth
        ▼
api.studafy.com  (existing Bun/Hono API on Fly)  ── new /v1/school-portal/* routes
        │  security-definer SQL functions, read-only for the portal
        ▼
Supabase Postgres (existing)  ── new tables in schema "private"
```

- **No new server.** The website is static files; all data comes from the
  existing API, which gets new routes. The worker gets one small job
  (the notices in 6.2), sent through the existing notification outbox.
- **Same accounts.** Supabase Auth, the same project as the app.
- **Same rules as the rest of Studafy:** append-only migrations, the
  route catalogue, permission checks in the API **and** again in SQL,
  pgTAP tests, generated OpenAPI and Dart client.

### 7.2 Naming

- Product name: **Studafy School Portal**.
- Code name: **`school-portal`** (API folder `apps/api/src/school-portal/`,
  contracts `packages/contracts/src/v1/schoolPortal.ts`, SQL prefix
  `school_portal_`).
- **Do not** reuse `apps/api/src/school-admin/`, `private.is_school_admin`,
  `public.memberships` admin rows, `private.api041_class_writer` or
  `private.is_class_staff`. Those are the platform operator's old
  school-setup paths. The portal administrator is **not** a member of any
  school and never gets a `memberships` row, so no existing staff check can
  ever let them in.
- The word "school" in the current database means a *teacher workspace*
  (each teacher has their own). The portal's school is a different thing:
  in SQL it is a **`school_portal_org`**, never a row in `public.schools`.

### 7.3 Data model (new tables, all in `private`)

| Table | Holds | Key columns |
|---|---|---|
| `school_portal_orgs` | A school's page | `id`, `name`, `country`, `city`, `kind`, `status` (`pending_check`, `active`, `suspended`, `closed`), `created_by`, `checked_by`, `checked_at`, timestamps |
| `school_portal_admins` | Who administers which org | `org_id`, `user_id`, `job_title`, `phone`, `added_by`, `removed_at`; unique live (`org_id`, `user_id`) |
| `school_portal_codes` | The current code | `org_id`, `code_hash` (sha-256, never the plain code), `created_at`, `revoked_at`; one live code per org |
| `school_portal_teacher_links` | A teacher's link | `id`, `org_id`, `teacher_id`, `status` (`pending`, `linked`, `declined`, `unlinked`), `share_all` (bool), `requested_at`, `decided_at`, `ended_at`, `ended_by` |
| `school_portal_shared_classes` | Classes a teacher chose (when `share_all` is false) | `link_id`, `classroom_id`, `shared_at`, `ended_at` |
| `school_portal_views` | The activity record | `admin_id`, `org_id`, `classroom_id`, `view` (`roster`, `assignments`, `tests`, `marks`, `attendance`), `at` |

Notes:

- A **teacher** links with their whole account. Their classes are in their
  own teacher workspace (`public.schools` + `public.classrooms`); a class
  is "shared" when the link is `linked` and either `share_all` is true and
  the teacher is a teacher of that class (`private.coursework_teacher`), or
  the class is in `school_portal_shared_classes` without `ended_at`.
- How the code works: the teacher types the code; the server hashes it and
  finds the live org; it creates a `pending` link and returns the org's
  public details for the teacher to confirm; the teacher's **Link**
  confirms it (`linked`). There is no step where the school approves: the
  code itself is the school's invitation. A code is rate-limited
  (10 tries per teacher per hour) and is never shown again in full after it
  is replaced.
- Account deletion: the teacher's links end and their rows are deleted with
  the account; an administrator's deletion removes their admin row; an org
  with no administrator left is closed. Add both to the two existing
  deletion paths.
- Data export: add the teacher's links, and an administrator's org and
  activity record, to the existing export.
- Retention: `school_portal_views` kept 12 months, then deleted by the
  retention job (`TODO(legal)` to confirm).

### 7.4 SQL functions

All `security definer`, `set search_path = ''`, owner `postgres`, execute
granted only to `studafy_api_runtime` (same pattern as
`private.api059_query/command` for marking). Every function:

1. checks `auth.uid()` is a live admin of the org (portal reads), or is the
   teacher (teacher actions);
2. checks the org is `active`;
3. checks the class is shared **at this moment** (link `linked`, class
   shared, class not deleted);
4. returns only the columns in section 3 (names only for students; only
   `published` marks);
5. writes a `school_portal_views` row for every portal read.

Queries: `school_portal_orgs_mine`, `school_portal_dashboard`,
`school_portal_teachers`, `school_portal_classes`,
`school_portal_class_roster`, `school_portal_class_assignments`,
`school_portal_class_tests`, `school_portal_class_marks`,
`school_portal_class_attendance`, `school_portal_link_preview` (teacher,
by code), `school_portal_my_links` (teacher).

Commands: `school_portal_org_create`, `school_portal_code_rotate`,
`school_portal_link_request` (teacher enters code),
`school_portal_link_confirm`, `school_portal_link_set_classes`,
`school_portal_link_end` (teacher or admin), `school_portal_org_close`,
operator-only `school_portal_org_check` (approve / suspend).

Commands go through the existing idempotency records, like every other
command.

### 7.5 API routes

New file `apps/api/src/school-portal/routes.ts`, mounted in
`apps/api/src/composition/routes.ts`; routes appended to
`V1_ROUTE_CATALOGUE` in `packages/contracts/src/v1/routes.ts`; schemas in
`packages/contracts/src/v1/schoolPortal.ts`; permissions in
`apps/api/src/authorization/catalogue.ts` (self-scoped:
`school_portal.read`, `school_portal.manage`, `school_portal_link.manage`).

| Method and path | Who | Does |
|---|---|---|
| `GET /v1/school-portal/orgs` | admin | My school(s) and status |
| `POST /v1/school-portal/orgs` | signed-in user | Create a school (Turnstile token required) |
| `POST /v1/school-portal/orgs/{orgId}/code` | admin | Make a new code (returns it once) |
| `GET /v1/school-portal/orgs/{orgId}/dashboard` | admin | Counts and waiting list |
| `GET /v1/school-portal/orgs/{orgId}/teachers` | admin | Linked teachers |
| `POST /v1/school-portal/orgs/{orgId}/teachers/{linkId}/unlink` | admin | Unlink |
| `GET /v1/school-portal/orgs/{orgId}/classes` | admin | Shared classes |
| `GET /v1/school-portal/orgs/{orgId}/classes/{classId}/{view}` | admin | `roster`, `assignments`, `tests`, `marks`, `attendance` |
| `POST /v1/school-portal/orgs/{orgId}/close` | admin | Close the school's page |
| `POST /v1/me/school-links/preview` | teacher | Code → school details (no link made) |
| `POST /v1/me/school-links` | teacher | Link (all or chosen classes) |
| `GET /v1/me/school-links` | teacher | My links |
| `POST /v1/me/school-links/{linkId}/classes` | teacher | Change shared classes |
| `POST /v1/me/school-links/{linkId}/unlink` | teacher | Unlink |
| `POST /internal/school-portal/orgs/{orgId}/check` | operator | Approve / suspend |

- The switch `SCHOOL_PORTAL_ENABLED` (in `packages/config`, API and
  worker): when off, every route above answers **404** (as if it did not
  exist) and `GET /v1/me` returns `schoolPortal: false`.
- Route names must not contain words banned by the AI-072 guard
  (`apps/api/test/ai072/removal.test.ts`).
- Then `bun run generate` and `bun run generate:check` (OpenAPI and the
  Dart client).

### 7.6 The website

- **Where in the repo:** `apps/school-web/`, its own package
  (`@studafy/school-web`) in the Bun workspace.
- **Built with:** Vite + React + TypeScript, built to static files. It
  imports request/response types from `@studafy/contracts`, so the website
  and the API cannot drift apart.
- **Sign-in:** `@supabase/supabase-js` with the PKCE flow
  (`signInWithOAuth`) and three providers: Apple, Google and Microsoft
  (Supabase calls it `azure`). The site's return address is
  `https://school.studafy.com/auth/callback` (add it, and the staging
  address, to Supabase → Authentication → URL Configuration → Redirect
  URLs). The phone app already uses the same Supabase project's Google and
  Microsoft providers and, on iPhone, Apple; the website reuses them and
  adds only what a website needs:
  - **Google:** in Google Cloud Console, the existing *web* OAuth client
    used by Supabase needs nothing new (its redirect is Supabase's own
    `https://<project-ref>.supabase.co/auth/v1/callback`). Add
    `school.studafy.com` to the OAuth consent screen's authorised domains.
  - **Microsoft:** the existing Microsoft Entra app registration, with the
    tenant set to `common` so personal (Outlook, Hotmail) and work or
    school (Microsoft 365) accounts both work. Check that the `email` and
    `xms_edov` (email verified) optional claims are on, as Supabase asks.
  - **Apple (new for the web):** in Apple Developer → Certificates,
    Identifiers & Profiles: create a **Services ID** (for example
    `com.studafy.school.web`), tick *Sign in with Apple*, set the domain
    `<project-ref>.supabase.co` and the return URL
    `https://<project-ref>.supabase.co/auth/v1/callback`. In Supabase →
    Authentication → Providers → Apple, add the Services ID to the client
    ids (next to the app's bundle id `com.studafy.light`) and give the
    secret made from the Sign in with Apple key (`.p8`). **That secret
    expires after at most 6 months:** a calendar reminder and a line in
    `docs/deployment/school-portal.md` say how to make a new one. To email
    people who hid their address, register `studafy.com` and the sending
    address under *Sign in with Apple for Email Communication*. This needs
    the Apple account working again (the organisation migration finished).
  - The website shows a button only when its provider is set up (a small
    `providers` list in the site's config), so a missing provider never
    shows a broken button.
- **Talking to the API:** `fetch` with `Authorization: Bearer <access
  token>`, against `https://api.studafy.com`. The API's CORS allow-list
  gains exactly `https://school.studafy.com` (and the staging site's
  address), for `/v1/school-portal/*` and `/v1/me` only.
- **Languages:** English and Arabic message files; `dir="rtl"` for Arabic;
  numbers and dates through `Intl`.
- **Security:**
  - Strict Content-Security-Policy (only self, the API, Supabase,
    Turnstile); no inline scripts; `frame-ancestors 'none'`.
  - No third-party analytics or fonts from other sites (fonts bundled).
  - All user content (school, class, student names) rendered as text,
    never as HTML.
  - Session ends after 12 hours idle; sign-out clears storage.
- **Hosting:** a **new** Vercel project `studafy-school`, domain
  `school.studafy.com` (DNS is already on Vercel). **Never link this folder
  to the `waitlist-app` or `studafy-legal` projects.** Staging gets its own
  Vercel preview address.

---

## 8. Build instructions, step by step

Each step is its own commit on `feat/school-admin-web` (or a short branch
off it, merged back into it, never into `main`). Every step ends with its
tests passing.

### Step 0: Before writing code

1. Owner answers the open questions in [section 14](#14-open-questions-for-the-owner).
2. **Staging is ready** (needed because the test copy is switched off at
   launch): a separate Supabase project with fake data, a staging API and
   worker on Fly (`studafy-api-staging`, `studafy-worker-staging`), and the
   Vercel preview for the website. Never use the production database for
   this work.
3. Pick one **pilot school** the owner knows, to try it with real people
   (using staging first).
4. Owner fills in every `[OWNER: …]` in the "Who we are" page
   ([4.4](#44-who-we-are-page-about)).
5. Sign-in setup for the website ([7.6](#76-the-website)): the Apple
   Services ID and secret, the Microsoft tenant check, the Google
   authorised domain, and the redirect URLs, on staging first.

### Step 1: Database

1. New migration `supabase/migrations/<timestamp>_school_portal.sql`:
   tables (7.3), indexes, RLS on with **no** policies (only the functions
   read them), functions (7.4), grants.
2. Hook account deletion, data export and retention (7.3).
3. pgTAP test `supabase/tests/school_portal.sql`:
   - an admin sees only their own org;
   - a pending, declined or unlinked teacher's classes are invisible;
   - `share_all` versus chosen classes;
   - a class removed from sharing disappears at once;
   - students: names only;
   - marks: published only, never drafts or AI suggestions;
   - a suspended or pending org sees nothing;
   - a portal admin has no `memberships` row and no existing staff
     function lets them in (`coursework_teacher`, `coursework_staff`,
     `is_school_admin` all false);
   - every read writes one activity row;
   - deletion and export include the new rows;
   - the code is stored only as a hash and is rate-limited.
4. Run the tests on a **throwaway** database only (see the project's
   pgTAP notes), never the hosted one.

### Step 2: API

1. Contracts (`schoolPortal.ts`), catalogue entries, permissions (7.5).
2. Routes and repository in `apps/api/src/school-portal/`.
3. The switch `SCHOOL_PORTAL_ENABLED` (default **false** everywhere,
   including `fly.api.toml` and `fly.worker.toml`).
4. CORS allow-list for the portal origin, only on portal routes.
5. Tests: route tests with fakes; an integration test against the real
   SQL; the switch-off test (every route 404s); the catalogue mounting test.
6. `bun run generate` → `bun run generate:check`.

### Step 3: Notices (worker)

1. New notification template keys `school_portal.class_shared` and
   `school_portal.class_unshared`, emitted by the SQL commands into the
   existing outbox, recipients = the class's students and their linked
   parents. Quiet (no push sound), in-app list only, or push without
   sound (owner decides, 14).
2. Route the tap to the class (the deep-link table in
   `lib/app/notification_routes.dart`).
3. Worker and pgTAP tests.

### Step 4: Phone app (teacher side)

1. Data: `lib/features/school_portal/data/api_school_links_repository.dart`
   and domain models.
2. Screens: `lib/features/school_portal/presentation/` (enter code,
   confirm, choose classes, linked view) as in section 6.
3. Account entry for teachers, shown only when `schoolPortal: true`.
4. EN/AR strings; `flutter gen-l10n`.
5. Widget tests (enter code, wrong code, rate limit message, choose
   classes, unlink, switch off hides the entry) and a Dart bounds check.

### Step 5: Website

1. Create `apps/school-web/` (Vite + React + TS), add to the workspace,
   add its build and tests to CI (a job that runs only on this branch
   until the gate).
2. Public pages (section 4): landing page, `/app`, `/about`, `/contact`,
   with the shared header and footer, prerendered to HTML.
3. Sign-in with Apple, Google and Microsoft, then create school,
   dashboard, teachers, classes, class tabs, settings (section 5).
3. EN/AR, RTL, phone layout.
4. Tests: unit tests for data formatting; component tests for each
   screen's empty, loading, error and full states; an end-to-end test
   (Playwright) against staging with a fake school, teacher and class.
5. Security headers in `vercel.json` (CSP and friends); check them with
   a header scanner on the preview URL.

### Step 6: Operator tools

1. Approve / suspend a school (existing operator path, `/internal/...`).
2. An alert (existing Telegram relay) when a new school is waiting.

### Step 7: Legal and docs

1. Privacy policy and terms updates (section 9), new consent version with
   SHA-256 pins, like every earlier policy change.
2. School agreement (data processing agreement) template.
3. `docs/deployment/school-portal.md` (setup, switch, Vercel, Supabase
   redirect URLs), decision log entry, ADR "School Portal: read-only
   school view of teacher-shared classes".
4. Store listing note for the app update ("Teachers can now link their
   classes to their school").

### Step 8: Security review and pilot

1. Run `/security-review` on the branch and fix findings.
2. Pilot on staging with the pilot school (fake data first, then real
   teachers on staging only).
3. Fix what the pilot shows.

---

## 9. Privacy, legal and safety

### 9.1 Who is responsible for the data

Today, a teacher using Studafy on their own decides what happens with
their class's data, and Studafy processes it. When a teacher links a class
to a school, that **school** also receives the data. Before any real
school uses the portal:

- a **school agreement** (data processing agreement) signed by each
  school: what they see, that they keep it confidential, that they do not
  copy it out of the portal, who to contact;
- the **Privacy Policy** gains a section "Sharing classes with a school":
  what is shared, that the teacher decides, that students and parents are
  told, and that the school cannot see messages or AI chats;
- the **Terms** gain the administrator's duties;
- a short **DPIA** (data protection impact assessment) note, like the
  earlier ones;
- `TODO(legal)`: have a lawyer read the three documents before launch.

### 9.2 What the school never sees

Messages · AI tutor chats · notebooks · flashcards and quizzes · uploaded
files and hand-in files · draft marks · AI-suggested marks · parents'
details · students' email, phone, photo or date of birth · anything from
classes that are not shared.

### 9.3 Read-only, on purpose

No portal route writes to a class. The SQL functions for the portal have
no `insert`, `update` or `delete` on any class, coursework, mark or
attendance table. A pgTAP test proves it.

### 9.4 Telling students and parents

Students and parents of a shared class get a notice (6.2), and the class
page in the app shows "Shared with <school>" under the class name.

### 9.5 Stopping fake schools

Anyone could pretend to be a principal. Defences:

- Studafy checks each new school before its code works (phone call or
  official school email domain).
- The code alone does nothing: the teacher must see the school's details
  and confirm.
- The teacher can unlink at any time; the school stops seeing data at once.
- Codes are long, random, hashed, and rate-limited.

### 9.6 Children

Many students are under 13. The portal shows only what a school normally
holds anyway (class lists, work, marks, attendance), and only names. Any
later feature that lets a school contact children directly needs its own
review first.

---

## 10. Testing

| Level | What | Where |
|---|---|---|
| Database | Access rules, read-only proof, deletion, export, retention, code hashing | `supabase/tests/school_portal.sql` |
| API | Each route, permissions, switch off → 404, CORS only for the portal origin | `apps/api/test/school-portal/` |
| Worker | Notices to the right students and parents | `apps/worker/test/` |
| App | Teacher screens, switch, EN/AR | `test/features/school_portal/` |
| Website | Screens' states, RTL, end-to-end on staging | `apps/school-web/test/`, Playwright |
| Security | `/security-review`, CSP/header scan, a manual "try to see another school's class" test | Before the gate |
| Pilot | One real school on staging | Before the gate |

---

## 11. The release gate: when this may be merged

**All** of these must be true before a pull request from
`feat/school-admin-web` into `main` is even opened:

1. ✅ The first app version is **approved and live** on both the App Store
   and Google Play (the Apple organization migration is finished).
2. ✅ Staging exists and the full portal has been tested there.
3. ✅ The pilot school has used it on staging, and its feedback is fixed.
4. ✅ The Privacy Policy, Terms and school agreement are written, and a
   lawyer has read them (`TODO(legal)` removed).
5. ✅ `/security-review` has been run and every finding is fixed.
6. ✅ All CI jobs pass on the branch, including the new website job.
7. ✅ The owner says, in their own words, that it may be merged.

After merging, in this order:

1. Deploy the API and worker with `SCHOOL_PORTAL_ENABLED=false`.
2. Release the app update (store review) with the hidden teacher screen.
3. Publish the new Privacy Policy and Terms (`bun run legal:deploy`).
4. Deploy the website to `school.studafy.com`.
5. Switch `SCHOOL_PORTAL_ENABLED=true`, first for the pilot school's
   teachers only if section 14 chooses a gradual start.

---

## 12. How to keep the branch separate from `main`

### 12.1 Rules

- The branch is **`feat/school-admin-web`**. All portal work happens there
  or on short branches made from it and merged back into it.
- **Never** open a pull request from it into `main` until the gate
  (section 11). Pull requests for portal work target
  `feat/school-admin-web`, not `main`.
- Nothing from this branch is deployed to production. Staging deploys
  come from this branch.
- Fixes needed by the live app are made on `main` as usual, never here.

### 12.2 Keeping it up to date with `main`

About once a week, and always before a large step:

```sh
git fetch origin
git switch feat/school-admin-web
git merge origin/main        # merge, do not rebase a shared branch
# fix conflicts, run all tests, then
git push
```

### 12.3 Migrations on a long-lived branch

Supabase applies migrations in timestamp order, and production refuses a
migration older than the last one it has applied. A migration written on
this branch in November will be *older* than migrations merged to `main`
in December. So:

- Write the portal's migrations on this branch as usual.
- **Right before the merge into `main`**, rename each portal migration to a
  new timestamp later than everything on `main` (for example
  `202612150010_school_portal.sql`), run `bun run check:migrations`, and
  re-run all pgTAP tests.
- Never edit a migration that has already been applied to production
  (none of these will have been).

### 12.4 Protecting the branch (optional)

On GitHub, Settings → Branches → add a rule for `main` so it needs a
review, and add a label `do-not-merge` to any pull request from this
branch until the gate.

---

## 13. Later versions

| Version | Adds | Notes |
|---|---|---|
| 2 | **One code for many classes:** the school makes *groups* (for example "Grade 7 – Section A") of linked teachers' classes; a student enters the group code once and joins every class in it (each teacher can still remove a student). | Uses the existing class-join path for each class; teachers must have opted in to the group. |
| 2 | Export to Excel/PDF | After the school agreement covers it. |
| 3 | **Announcements** from the school to: all linked classes, one group, all parents, all teachers. | Through the existing notification outbox; needs moderation and a "school" sender label. |
| 3 | **Messages** between the school and parents or teachers | Needs its own safety review; never school-to-student direct messages without one. |
| 4 | Reports (attendance and marks across classes, trends) | |
| 4 | **School billing** by invoice (outside the app stores), and a paid "school plan" that, for example, gives Studafy Max to every student in the school. | Apple and Google allow selling to organisations outside in-app purchase. |
| 4 | Several administrator roles (principal, deputy, IT) | |

---

## 14. Open questions for the owner

1. **More than one administrator per school** in version 1, or exactly
   one? (Recommended: up to 3, added by the first.)
2. **How Studafy checks a school:** a phone call, the school's official
   email domain, or both?
3. **Notices to students and parents:** in-app only, or also a silent
   push?
4. **Gradual start:** switch on for the pilot school only first, or for
   everyone at once?
5. **Attendance:** totals only, or also each day's record per student?
6. **A teacher in two schools:** allowed (a teacher who works at two
   schools), or one school per teacher? (Recommended: allowed, each class
   shared with at most one school.)
7. **Name on the website:** "Studafy School Portal", or another name?
8. **Who we are page:** the story, and whether to show the team's names
   and photos (or leave the team out). The company details to show.
9. **Where the "about the app" pages live:** only on
   `school.studafy.com` (this plan), or also replace the waitlist page at
   `studafy.com` with them once the app is live? (Recommended: build them
   here first, and decide on `studafy.com` after launch; the
   `waitlist-app` Vercel project is never touched by this branch.)

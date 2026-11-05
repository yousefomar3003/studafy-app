# Studafy School Portal and studafy.com: plan and build instructions

> **Status: building started 2026-11-05, public pages first.** Every owner
> decision of 2026-11-05 is in this document
> ([section 14](#14-owner-decisions-and-open-questions)).
> This document lives only on the long-lived branch `feat/school-admin-web`.
> **Nothing on this branch is merged into `main` until every gate in
> [section 11.2](#112-portal-gate-merging-into-main) is met.** The version of
> Studafy in store review has no school administrator, and must not gain one
> by accident. The public website (static pages, no server, no database) is
> the one thing released earlier, from this branch, under its own gate
> ([11.1](#111-public-pages-release)).

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
14. [Owner decisions and open questions](#14-owner-decisions-and-open-questions)

---

## 1. What we are building, in one page

Two things, built together on this branch:

1. **The Studafy website at `https://studafy.com`.** Polished public pages
   about Studafy: the home page, the app's features, the School Portal, an
   about page and a contact page. It replaces the current waitlist site
   (another repo) once the app is live in both stores
   ([4.9](#49-moving-studafycom-from-the-waitlist-site)).
2. **Studafy School Portal at `https://school.studafy.com`.** A website for
   a school's principal or administrators. It is not part of the phone app.

In version 1 a school administrator can do two things:

1. **Link teachers to the school.** The administrator enters a teacher's
   **Studafy ID**. The teacher gets the request in the Studafy app, sees
   which school is asking and exactly what it will see, and **accepts or
   declines**. It works the same way a parent links to a student today: one
   side asks with the other's Studafy ID, the other side decides. The
   teacher can unlink at any time.
2. **See every class of linked teachers, read-only.** Students (with their
   emails, Studafy IDs and linked parents), lessons and files, homework and
   hand-ins, online tests and answers, all marks (published, unpublished and
   AI-suggested), each student's daily attendance, and wellbeing notes. The
   administrator **cannot change anything**, cannot message anyone, and
   never sees messages, AI Tutor chats, or students' own notebooks, notes,
   flashcards and quizzes.

Everything teachers do today stays exactly the same. A teacher who never
accepts a school's request notices nothing.

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
| **School administrator** (principal, head of school, school IT) | Website | Create the school's page; add up to two more administrators (3 in all); send link requests to teachers by their Studafy ID; see linked teachers and all their classes, read-only; unlink a teacher; close the school's page. |
| **Teacher** | Phone app | Show and copy their Studafy ID; see a school's request (who asks, what the school will see); accept or decline; report a school; see that their classes are visible to the school; unlink at any time. |
| **Student** | Phone app | Nothing to do, and no notice ([9.4](#94-no-notices-to-students-and-parents)). |
| **Parent** | Phone app | Nothing to do, and no notice. |
| **Studafy (platform operator)** | Existing operator tools | No approval step: anyone can create a school. Studafy reads reports from teachers and can suspend a school for abuse ([9.5](#95-risks-the-owner-accepted)). |

The administrator is **not** a new role in the phone app. An administrator
signs in to the website with an Apple, Google or Microsoft (Outlook,
Hotmail, Microsoft 365) account. If the same person is also a teacher, they
keep their teacher account in the app; the two do not mix.

---

## 3. Version 1 scope (and what is deliberately left out)

### In version 1

- Public website at `studafy.com` (section 4): home, features, schools,
  about and contact pages.
- Sign in with Apple, Google or Microsoft (Outlook, Hotmail, Microsoft
  365) on `school.studafy.com`.
- Create a school: name, country, city, type, the administrator's job
  title and a contact email. Anyone can create one; it is active at once.
  There is no check by Studafy.
- Up to **3 administrators** per school; the first adds the others.
- **Link a teacher:** enter the teacher's Studafy ID; the request waits
  for the teacher. Request list with status: *Waiting for the teacher*,
  *Linked*, *Declined*, *Unlinked*, *Expired*.
- When linked, **all** of the teacher's classes are visible, including
  classes created later, for as long as the link lasts. No class picking.
- **One school at a time:** a teacher is linked with at most one school.
  Accepting another school's request first asks the teacher to unlink the
  current one, so no school ever sees another school's classes.
- Per class, read-only:
  - **Students:** name, email, Studafy ID; the parents linked to each
    student, with their names and emails.
  - **Lessons**, the teacher's files and the class's **announcements**
    (posts to the whole class; never private messages).
  - **Assignments** with every student's hand-in (files, photos, typed
    answers).
  - **Online tests** with every student's answers.
  - **Marks:** all of them, each labelled *Published*, *Not published* or
    *AI suggestion*.
  - **Attendance:** each student's record for every day.
  - **Wellbeing notes** the teacher wrote.
- Unlink a teacher (from either side).
- English and Arabic, with right-to-left layout for Arabic.
- An activity record: every page and file the administrator opens is
  written to the audit log (who, which class, which student or file, when).

### Deliberately not in version 1

- No editing of anything: classes, marks, students, attendance, notes.
- No messages, announcements or notifications from the school.
- Never shown: messages (any conversation), students' AI Tutor chats,
  students' personal notebooks and notes, flashcards and quizzes.
- No notices to students or parents (the privacy policy and terms cover
  the sharing).
- No check of schools by Studafy.
- No one code that puts students into many classes (version 2).
- No billing. Version 1 is free.
- No school administrator inside the phone app.
- No exporting to Excel/PDF (version 2, once the data-protection agreement
  covers it).

---

## 4. The website's public pages

The public pages are what anyone sees at `https://studafy.com`. They say
who Studafy is, what the app does, and plainly what the School Portal does
and does **not** do, because principals, teachers and parents will all
read them. English and Arabic; the language follows the browser, with a
switch in the header (Arabic pages under `/ar/...`).

### 4.1 Addresses and pages

| Address | Page | Section |
|---|---|---|
| `studafy.com/` | Home: Studafy, for everyone | [4.2](#42-the-home-page) |
| `studafy.com/features` | The app in detail | [4.3](#43-the-features-page) |
| `studafy.com/schools` | Studafy School Portal (hidden until the portal's release) | [4.4](#44-the-schools-page) |
| `studafy.com/about` | About Studafy | [4.5](#45-the-about-page) |
| `studafy.com/contact` | Contact | [4.6](#46-the-contact-page) |
| `school.studafy.com` | The portal: sign-in and screens | [section 5](#5-screens-of-the-portal) |
| Privacy, Terms | Links to `https://legal.studafy.com/privacy` and `/terms` (never copies) | |

`www.studafy.com` redirects to `studafy.com`.

**The portal switch.** The public pages go live once the app is in both
stores, **before** the portal is ready. Until the portal passes its gate,
the build switch `VITE_PORTAL_PUBLIC` (off by default) hides the
`/schools` page, every link to it, and every **Sign in** button. With the
switch off, `/schools` is not built at all (no page, not in the sitemap).

Every public page has the same header and footer:

- **Header:** Studafy logo (goes to `/`) · **Features** · **For schools**
  (switch on only) · **About** · **Contact** · language switch (English /
  العربية) · **Sign in** button (switch on only, goes to
  `https://school.studafy.com/signin`) · **Get the app** button. On a phone
  the links fold into a menu button.
- **Footer:** © Studafy · Features · For schools (switch on only) · About ·
  Contact · hello@studafy.com · Privacy · Terms · language switch (the
  store badges sit in the home page's top and closing sections). No company
  name, number or address anywhere on the site.

Built (2026-11-05): the public pages in `apps/school-web/`; setup, settings
and the domain move are in `docs/deployment/studafy-web.md`.

### 4.2 The home page

1. **Hero:**
   - Heading: **"One app for a class's everyday work."**
   - Text: "Lessons, homework, online tests, marks and attendance for
     teachers, students and parents. In English and Arabic."
   - Buttons: App Store and Google Play badges · **See the features**.
   - Image: a stack of three phone mockups (teacher, student, parent) from
     the store screenshots, with a gentle entrance animation.
2. **For teachers · For students · For parents:** three cards, each with a
   screenshot and three lines taken from [4.3](#43-the-features-page).
3. **A day in Studafy:** alternating text-and-phone rows: share a lesson;
   set homework and see who handed in; build an online test; publish marks
   when ready; take attendance.
4. **Study help:** the AI Tutor, Studafy Plus and Studafy Max, with the
   line "The AI Tutor's answers can be wrong, so check them."
5. **Privacy, built in:** no ads; we never sell your data; marks reach
   students and parents only when the teacher publishes them; download
   your data or delete your account from inside the app.
6. **English and Arabic:** the same screen side by side in both languages,
   with the right-to-left layout.
7. **For schools** (switch on only): one band about the School Portal with
   a link to `/schools`.
8. **Free where it matters:** "Lessons, homework, marks and attendance are
   free. Studafy Plus, Studafy Max, Family+ and Studafy AI Marking are
   optional monthly subscriptions." No prices.
9. **Get the app:** the store badges again.

### 4.3 The features page

What the whole app does, for someone who has never used it. The text comes
from the store listing (`docs/store/listing-copy.md` on `main`), so the
website never promises more than the app does. Re-read that file when
writing this page, and again before each release: anything added to or
removed from the listing is added to or removed from this page.

1. **Top:** heading **"Studafy: lessons, homework, tests, marks and
   attendance in one app."** Text: "For teachers, students and parents.
   In English and Arabic. No ads, and we never sell your data." App
   Store and Google Play badges. Three phone screenshots (teacher,
   student, parent), the same pictures as the store listing.
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
5. **For schools** (switch on only): one paragraph about the School Portal
   and a link to `/schools`.
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

### 4.4 The schools page

Built only when `VITE_PORTAL_PUBLIC` is on. It must describe exactly what
the school sees ([9.2](#92-what-the-school-sees-and-never-sees)), no more
and no less.

1. **Hero:**
   - Heading: **"Every class in your school, in one place."**
   - Text: "Studafy School Portal lets a school see the classes, work,
     marks and attendance of the teachers who accept its request. Read-only,
     and teachers stay in control."
   - Buttons: **Create your school's page** (primary, goes to
     `https://school.studafy.com/signin`) · **How it works** (scrolls
     down).
   - Image: a laptop mockup of the dashboard with invented data.
2. **How it works, in three steps:**
   1. "**Create your school's page.** Sign in with Apple, Google or
      Microsoft. It takes a minute."
   2. "**Ask your teachers for their Studafy ID.** Enter it, and each
      teacher accepts the request in the Studafy app."
   3. "**See every class in one place.** Students, lessons, homework,
      tests, marks and attendance, always up to date."
3. **What you can see:** cards with icons: Classes and students (with
   emails and linked parents) · Lessons and files · Homework and hand-ins ·
   Online tests and answers · Marks, published and not yet published ·
   Attendance, day by day · Wellbeing notes.
4. **Teachers stay in control:** "Nothing is visible until a teacher
   accepts. A teacher can unlink at any time, and the school stops seeing
   their classes at once. The portal is read-only: it cannot change
   anything."
5. **Privacy, in plain words:**
   - "Only the classes of teachers who accept."
   - "Messages, AI Tutor chats and students' personal notes are never
     shown to a school."
   - "Every page an administrator opens is recorded."
   - Link: "Read the Privacy Policy" (`https://legal.studafy.com/privacy`).
6. **For teachers:** "Already teaching on Studafy? Nothing changes for you
   unless you accept a school's request." Store badges.
7. **Questions (FAQ):**
   - *Does it cost anything?* "The portal is free in its first version."
   - *Can the school change marks?* "No. The portal is read-only."
   - *Can the school read messages?* "No."
   - *What if a teacher leaves the school?* "They unlink in the app, and
     the school stops seeing their classes at once."
   - *Who can create a school page?* "Anyone at a school. Nothing is
     visible until a teacher accepts the school's request."
   - *Where does a teacher find their Studafy ID?* "In the Studafy app:
     Account → Studafy ID."
   - *Which accounts can I sign in with?* "Apple, Google or Microsoft
     (including Outlook, Hotmail and Microsoft 365 school accounts)."
   - *Do students need to do anything?* "No. Students and parents keep
     using the Studafy app as they do now."

### 4.5 The about page

Written in a confident company voice. No team section, no founder names,
no personal story, and **no invented facts**: no founding dates, user
numbers, customers, partners or awards.

1. **Heading:** "About Studafy".
2. **Our mission:** "We make the everyday work of a class simpler for
   teachers, clearer for students and easier to follow for parents, in
   English and Arabic."
3. **What we build:** two short paragraphs: one app that brings lessons,
   homework, tests, marks, attendance and messages together, so a class's
   work lives in one place instead of many; and careful AI that helps
   students study and helps teachers mark, while people make the
   decisions.
4. **What we believe** (four cards, each a promise the app already keeps):
   - **Teachers decide.** Marks stay private until a teacher publishes
     them, and AI only suggests.
   - **Privacy first.** No ads, we never sell data, and a school sees a
     teacher's classes only after the teacher accepts.
   - **Built for English and Arabic.** Written, not machine-translated,
     with a real right-to-left layout.
   - **Free where it matters.** Lessons, homework, marks and attendance
     are free.
5. **Get in touch:** link to `/contact`.

### 4.6 The contact page

- Email `hello@studafy.com` (a `mailto:` link) for questions, schools,
  privacy requests and press.
- Ready-made links with a subject line: "Schools", "Privacy request",
  "Help with the app", "Press".
- Text: "We usually answer within two working days."
- **No contact form in version 1:** a form needs storage, spam protection
  and its own privacy text; email is enough to start.
- Links to the Privacy Policy and Terms.

### 4.7 Design and motion

Company-grade and polished, matching the app:

- **Brand:** colours from the app (`lib/core/studafy_design.dart`): navy
  `#161551`, ink `#0E0D3A`, indigo `#34319A`, teal `#4E8EA2`, sky
  `#7BBDE8`, frost `#BDD8E9`, canvas `#F7FAFD`, wash `#EFF5FA`, hairline
  `#E2ECF3`. Logo and icon from `assets/brand/source/` (`logo.svg`,
  `logo_white.svg`, `icon_s.svg`).
- **Pictures:** device mockups (phone and laptop frames drawn in CSS/SVG)
  holding the store screenshots from `docs/store/screenshots/ios/en` and
  `/ar` (Arabic pages use the Arabic ones). Before the public release,
  retake any screenshot the store listing says is out of date (the tab bar
  should show Messages, not Announcements).
- **Motion:** tasteful, never in the way: scroll-in reveals, a slow
  parallax on the hero's phone stack, soft hover lifts on cards and
  buttons, smooth section changes. **`prefers-reduced-motion` turns every
  animation off.** No autoplaying video, no scroll-jacking.
- **Type:** fonts are bundled with the site (Latin and Arabic families,
  `woff2`, self-hosted), never loaded from another site.
- **Quality bar:** WCAG 2.2 AA (contrast, keyboard, focus rings, alt
  text); Lighthouse 95+ for performance, accessibility, best practices and
  SEO on a phone profile; largest content shown within 2.5 s on 4G.

### 4.8 Rules for every public page

- No tracking scripts, no ads, no third-party analytics. The public pages
  call no API at all.
- Must work on a phone browser too (single column below 720 px).
- Images use invented people and schools only.
- Claims about the app follow the store listing's rules: only what the
  code does, no "best" or "#1", no competitor names, no prices, nothing
  aimed at children in marketing language.
- App Store and Google Play badges use the official artwork and the
  stores' badge rules, and link to the real store pages.
- The public pages are built to plain HTML at build time (prerendered), so
  they load fast on slow phones and search engines can read them. Each
  page has its own title, description, social-share image, and
  `hreflang` links between English and Arabic; a `sitemap.xml` and
  `robots.txt` are generated.
- Arabic copy is written, not machine-translated, and reviewed like the
  app's Arabic strings (`lib/l10n/app_ar.arb` style: "Studafy", plan and
  product names in Latin letters).

### 4.9 Moving studafy.com from the waitlist site

`studafy.com` today is the `waitlist-app` Vercel project (another repo).
Its DNS zone lives at the Vercel **account** level, not inside that
project, so moving the website changes no DNS records.

1. The new site is its own Vercel project, **`studafy-web`**, in the same
   Vercel account. It is tested on its `….vercel.app` address first.
2. **Export the waitlist sign-ups** from wherever the old site stores
   them, before anything changes.
3. In `studafy-web` → **Settings → Domains**, add `studafy.com` and
   `www.studafy.com`; Vercel offers to move them from `waitlist-app`.
   Confirm. Certificates are issued automatically.
4. Keep `waitlist-app` (with no domain) for a few weeks: moving the domain
   back is the rollback.
5. Later, at the portal's release, add `school.studafy.com` to the same
   `studafy-web` project.
6. **Never touch:** `legal.studafy.com` and `app.studafy.com` (project
   `studafy-legal`; the app links and sign-in return depend on
   `app.studafy.com`), `api.studafy.com` (Fly), and the email records (MX
   and friends) for `hello@studafy.com`.
7. **Never** run `vercel link` from this folder to `waitlist-app` or
   `studafy-legal`.

---

## 5. Screens of the portal

All screens at `school.studafy.com`. Left side menu on a computer; bottom
menu on a phone.

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
  also asks for a **contact email**, because teachers see the
  administrator's email before they accept.
- **Same person, same button:** signing in with a different button reaches
  the same account only when it carries the same email address (an Apple
  hidden address never matches). The sign-in page says: "Use the same way
  to sign in each time."
- Errors are plain: "Sign-in was cancelled", "That account could not sign
  in. Try another way." Nothing technical is shown.

### 5.2 Create your school (first sign-in only)

Fields: school name · country · city · type (public / private /
international / other) · your job title · a contact email (filled in from
the sign-in and editable; required when the sign-in address is an Apple
hidden one) · tick box "I am authorised by this school to create its
Studafy page". Turnstile check (against bots only). Button **Create**.

The school is **active at once**; there is no waiting for Studafy.

### 5.3 Dashboard

- School name and status (*Active* / *Suspended*).
- **Link a teacher** card: a field for the teacher's Studafy ID and a
  **Send request** button, with the sentence "Teachers find their Studafy
  ID in the Studafy app: Account → Studafy ID." A wrong ID says "No
  teacher has that Studafy ID."
- Counts: linked teachers, classes, students.
- Requests waiting for the teacher (with **Cancel request**).

### 5.4 Teachers

Table: name · email · subjects (from their classes) · status · classes ·
linked since · **Unlink** (with a confirmation).

### 5.5 Classes

Table of every class of every linked teacher: class name · teacher · term ·
students · last activity. Search box and filters (teacher, term).

### 5.6 One class

Header: class name, teacher, term, number of students. Tabs:

| Tab | Shows |
|---|---|
| Overview | Upcoming assignments and tests; average marks; attendance rate this month. |
| Students | Name · email · Studafy ID · linked parents (name and email), alphabetical. |
| Lessons | Lessons by date with their notes, links and files (files open through the delivery route), and the class's announcements, read-only. |
| Assignments | Title · due date · handed in (n of m) · marked (n of m). Opening one lists every student's hand-in: typed answer, photos and files. |
| Online tests | Title · date · sat (n of m) · average mark. Opening one shows every student's answers and marks. |
| Marks | Grid of students × items; every mark labelled *Published*, *Not published* or *AI suggestion*; averages per student and per item. |
| Attendance | A grid of students × days (present / absent / late / excused), plus term totals. |
| Wellbeing | The teacher's wellbeing notes per student (strengths, concerns), with dates. |

Every table says when the data was last updated, and shows a clear empty
state ("No marks yet").

### 5.7 Settings

- School details (name, city, type, contact email), editable at once.
- **Administrators:** up to 3. The first administrator adds others by
  email (they sign in with that address to accept) and can remove them.
  The last administrator cannot remove themselves without closing the
  school.
- **Close the school's page:** unlinks every teacher and removes the
  school's page.

---

## 6. The teacher's side, in the phone app

This is the only part of the phone app that changes, and it needs a new
app version through store review. It is built on this branch with
everything else and switched off until the release gate.

### 6.1 The teacher's Studafy ID

- Today only students have a Studafy ID (the one parents use to link;
  `supabase/migrations/202609290006_guardian_links_students_only.sql`).
  **Teachers get one too**, from the same scheme: same format, same
  lookup, same rate limits and Turnstile check as the student-ID lookup.
- **Where:** Account → **Studafy ID** (teachers), with **Copy** and
  **Share**, and the line "Give this to your school so it can ask to link."

### 6.2 A school's request

Modelled on the guardian link flow (request → decision by the person asked).

- The teacher gets an in-app notification and a push: "*Cedar Grove
  School* asks to link with you."
- **Request screen** shows:
  - the school's name, city, country and type;
  - the administrator's name, job title and email;
  - **What the school will see**, as a list: all your classes, including
    new ones; every student's name, email and Studafy ID; linked parents'
    names and emails; lessons, your files and class announcements; hand-ins and test answers;
    all marks, including unpublished and AI-suggested ones; daily
    attendance; your wellbeing notes;
  - **What it will never see:** messages, students' AI Tutor chats,
    students' own notebooks, notes, flashcards and quizzes;
  - "The school can only look, never change anything. You can unlink at
    any time."
  - **Accept** · **Decline** · **Report this school**.
- If the teacher is already linked with another school, **Accept** first
  says: "You are linked with *<school>*. To link with *<new school>*, you
  will be unlinked from *<school>*, which will stop seeing your classes."
  with **Unlink and accept** · **Cancel**. The two steps happen in one
  database transaction.
- A request expires after 14 days.

### 6.3 While linked

- A banner on the teacher's Today and Classes screens: "**Your classes are
  visible to *Cedar Grove School*.**" with **Unlink** one tap away (with a
  confirmation).
- Account → **Schools** lists linked schools and past requests, with
  **Unlink** and **Report**.
- Unlinking takes effect at once; the school sees nothing more.

### 6.4 Strings

New EN/AR strings in `lib/l10n/app_en.arb` and `app_ar.arb`, then
`flutter gen-l10n`. School and administrator names are user content: show
them through the existing `user_content_text.dart` helpers (bidi
isolation).

### 6.5 The switch

The app shows these screens only when `GET /v1/me` returns
`schoolPortal: true` (a new field the server sets from
`SCHOOL_PORTAL_ENABLED`). Old app versions ignore the field. This lets the
app version with the screens go through review and be released while the
feature stays off, then be switched on from the server for everyone at
once.

---

## 7. How it is built: architecture

### 7.1 The pieces

```
studafy.com          (static public pages)  ┐
school.studafy.com   (static portal app)    ┘  one Vercel project "studafy-web"
        │  portal only: HTTPS, Bearer token from Supabase Auth
        ▼
api.studafy.com  (existing Bun/Hono API on Fly)  ── new /v1/school-portal/* routes
        │  security-definer SQL functions, read-only for the portal
        ▼
Supabase Postgres (existing)  ── new tables in schema "private"
```

- **No new server.** The website is static files; the public pages call
  nothing; the portal's data comes from the existing API, which gets new
  routes. The worker sends one new teacher notice (the request in 6.2)
  through the existing notification outbox.
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
| `school_portal_orgs` | A school's page | `id`, `name`, `country`, `city`, `kind`, `contact_email`, `status` (`active`, `suspended`, `closed`), `created_by`, `suspended_by`, `suspended_at`, `suspended_reason`, timestamps |
| `school_portal_admins` | Who administers which org | `org_id`, `user_id`, `job_title`, `added_by`, `removed_at`; unique live (`org_id`, `user_id`); at most **3** live per org (checked in SQL) |
| `school_portal_admin_invites` | An administrator adding another | `org_id`, `email`, `invited_by`, `created_at`, `accepted_at`, `revoked_at` |
| `school_portal_teacher_links` | A school's request and the link | `id`, `org_id`, `teacher_id`, `requested_by` (admin), `status` (`pending`, `linked`, `declined`, `cancelled`, `expired`, `unlinked`), `requested_at`, `decided_at`, `ended_at`, `ended_by`; one live (`pending` or `linked`) row per (`org_id`, `teacher_id`), and at most one `linked` row per `teacher_id` (unique partial index: one school at a time) |
| `school_portal_reports` | A teacher reporting a school | `id`, `org_id`, `link_id`, `reported_by`, `reason`, `created_at`, `handled_at`, `handled_by` |
| `school_portal_views` | The activity record | `admin_id`, `org_id`, `classroom_id`, `student_id` (nullable), `file_id` (nullable), `view` (`roster`, `lessons`, `file`, `assignments`, `hand_in`, `tests`, `test_answers`, `marks`, `attendance`, `wellbeing`), `at` |

Notes:

- **Teachers' Studafy IDs:** extend the existing student Studafy ID to
  teachers (same table or column and generator; no second scheme). The
  lookup by ID is shared with the guardian flow's protections.
- **Which classes are visible:** every class where the teacher is a
  teacher (`private.coursework_teacher`) while the link is `linked`,
  including classes created after linking. A class with two teachers is
  visible if either of them is linked.
- **Request rules:** an admin enters a teacher's Studafy ID; the server
  finds the teacher (only teacher accounts), creates a `pending` link and
  queues the teacher's notice. Rate limits: 30 requests per org per day; 10
  ID lookups per admin per hour; a teacher who declined cannot be asked
  again by the same org for 30 days; a teacher can have at most 5 pending
  requests. Requests expire after 14 days (retention job).
- **Account deletion:** the teacher's links end and their rows are deleted
  with the account; an administrator's deletion removes their admin row; an
  org with no administrator left is closed. Add both to the two existing
  deletion paths.
- **Data export:** add the teacher's links and reports, and an
  administrator's org and activity record, to the existing export.
- **Retention:** `school_portal_views` kept 12 months, then deleted by the
  retention job (`TODO(legal)` to confirm).

### 7.4 SQL functions

All `security definer`, `set search_path = ''`, owner `postgres`, execute
granted only to `studafy_api_runtime` (same pattern as
`private.api059_query/command` for marking). Every portal read:

1. checks `auth.uid()` is a live admin of the org;
2. checks the org is `active`;
3. checks the class belongs to a teacher whose link is `linked` **at this
   moment** (class not deleted);
4. returns only the data in section 3: never messages, AI Tutor chats,
   personal notebooks or notes, flashcards or quizzes;
5. writes a `school_portal_views` row.

Teacher actions check `auth.uid()` is the teacher of the link.

Queries: `school_portal_orgs_mine`, `school_portal_dashboard`,
`school_portal_teachers`, `school_portal_classes`,
`school_portal_class_roster` (students, emails, Studafy IDs, linked
parents and their emails), `school_portal_class_lessons`,
`school_portal_class_assignments`, `school_portal_hand_in`,
`school_portal_class_tests`, `school_portal_test_answers`,
`school_portal_class_marks` (all marks with their state, including
AI-marking suggestions), `school_portal_class_attendance` (daily
records), `school_portal_class_wellbeing`; teacher side
`school_portal_my_links`, `school_portal_link_request_detail`.

Commands: `school_portal_org_create`, `school_portal_org_update`,
`school_portal_admin_invite`, `school_portal_admin_accept`,
`school_portal_admin_remove`, `school_portal_link_request` (admin enters
a Studafy ID), `school_portal_link_cancel` (admin),
`school_portal_link_decide` (teacher accepts or declines),
`school_portal_link_end` (teacher or admin), `school_portal_report`
(teacher), `school_portal_org_close`, operator-only
`school_portal_org_suspend` (suspend / restore).

**Files:** a portal administrator opens a lesson file or a hand-in only
through the existing re-authorizing delivery route
(`apps/api/src/files/routes.ts`): its authorization SQL gains a portal
branch (live admin of an active org, linked teacher of the file's class)
and writes a `file` view row. Never a storage-signed URL (the FILE-051
rule in `scripts/check-file-boundaries.ts`).

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
| `PATCH /v1/school-portal/orgs/{orgId}` | admin | Edit school details |
| `POST /v1/school-portal/orgs/{orgId}/admins` | admin | Invite an administrator (up to 3 in all) |
| `POST /v1/school-portal/admin-invites/{inviteId}/accept` | invited user | Become an administrator |
| `POST /v1/school-portal/orgs/{orgId}/admins/{userId}/remove` | admin | Remove an administrator |
| `GET /v1/school-portal/orgs/{orgId}/dashboard` | admin | Counts and waiting requests |
| `POST /v1/school-portal/orgs/{orgId}/link-requests` | admin | Request a link by Studafy ID (Turnstile token required) |
| `POST /v1/school-portal/orgs/{orgId}/link-requests/{linkId}/cancel` | admin | Cancel a waiting request |
| `GET /v1/school-portal/orgs/{orgId}/teachers` | admin | Linked teachers |
| `POST /v1/school-portal/orgs/{orgId}/teachers/{linkId}/unlink` | admin | Unlink |
| `GET /v1/school-portal/orgs/{orgId}/classes` | admin | All classes of linked teachers |
| `GET /v1/school-portal/orgs/{orgId}/classes/{classId}/{view}` | admin | `roster`, `lessons`, `assignments`, `tests`, `marks`, `attendance`, `wellbeing` |
| `GET /v1/school-portal/orgs/{orgId}/classes/{classId}/assignments/{assignmentId}/hand-ins` | admin | Every student's hand-in |
| `GET /v1/school-portal/orgs/{orgId}/classes/{classId}/tests/{testId}/answers` | admin | Every student's answers |
| `POST /v1/school-portal/orgs/{orgId}/close` | admin | Close the school's page |
| `GET /v1/me/school-links` | teacher | My requests and links |
| `GET /v1/me/school-links/{linkId}` | teacher | One request: the school, who asks, what it will see |
| `POST /v1/me/school-links/{linkId}/decision` | teacher | Accept or decline |
| `POST /v1/me/school-links/{linkId}/unlink` | teacher | Unlink |
| `POST /v1/me/school-links/{linkId}/report` | teacher | Report a school |
| `POST /internal/school-portal/orgs/{orgId}/suspend` | operator | Suspend / restore |

- The teacher's Studafy ID is returned by the existing account endpoint
  that already returns a student's.
- The switch `SCHOOL_PORTAL_ENABLED` (in `packages/config`, API and
  worker): when off, every route above answers **404** (as if it did not
  exist) and `GET /v1/me` returns `schoolPortal: false`. When on, it is on
  for everyone.
- Route names must not contain words banned by the AI-072 guard
  (`apps/api/test/ai072/removal.test.ts`).
- Then `bun run generate` and `bun run generate:check` (OpenAPI and the
  Dart client).

### 7.6 The website

- **Where in the repo:** `apps/school-web/`, its own package
  (`@studafy/school-web`) in the Bun workspace. It holds both the public
  pages and the portal. Being a workspace member, it needs its own entry
  in `scripts/check-bounds.ts` (`ALLOWED`), and follows the repo's
  `deno fmt` / `deno lint`.
- **Built with:** Vite + React + TypeScript, built to static files. Public
  pages are prerendered to HTML; the portal is a single-page app. It
  imports request/response types from `@studafy/contracts`, so the website
  and the API cannot drift apart.
- **Two hosts, one project:** Vercel project `studafy-web` serves the
  public pages on `studafy.com` and the portal on `school.studafy.com`,
  routed by host in `vercel.json`.
- **The switch:** `VITE_PORTAL_PUBLIC` (build time, default off) controls
  the `/schools` page, links to it and every sign-in button
  ([4.1](#41-addresses-and-pages)).
- **Sign-in (portal only):** `@supabase/supabase-js` with the PKCE flow
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
    `studafy.com` to the OAuth consent screen's authorised domains.
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
- **Talking to the API (portal only):** `fetch` with `Authorization: Bearer
  <access token>`, against `https://api.studafy.com`. The API's CORS
  allow-list gains exactly `https://school.studafy.com` (and the staging
  site's address), for `/v1/school-portal/*`, the file delivery route and
  `/v1/me` only. `studafy.com` gets no API access.
- **Languages:** English and Arabic message files; `dir="rtl"` for Arabic;
  numbers and dates through `Intl`.
- **Security:**
  - Strict Content-Security-Policy. Public pages: only self; no inline
    scripts; `frame-ancestors 'none'`. Portal: self, the API, Supabase,
    Turnstile.
  - No third-party analytics or fonts from other sites (fonts bundled).
  - All user content (school, class, student names, typed answers, notes)
    rendered as text, never as HTML.
  - Portal session ends after 12 hours idle; sign-out clears storage.
- **Hosting:** Vercel project **`studafy-web`** (moving `studafy.com` is in
  [4.9](#49-moving-studafycom-from-the-waitlist-site)). **Never link this
  folder to the `waitlist-app` or `studafy-legal` projects.** Staging gets
  its own Vercel preview address.

---

## 8. Build instructions, step by step

Each step is its own commit on `feat/school-admin-web` (or a short branch
off it, merged back into it, never into `main`). Every step ends with its
tests passing.

### Step 0: Before writing code

1. Owner decisions: done ([section 14](#14-owner-decisions-and-open-questions)).
2. **Staging is ready** before any database or API work (needed because
   the test copy is switched off at launch): a separate Supabase project
   with fake data, a staging API and worker on Fly
   (`studafy-api-staging`, `studafy-worker-staging`), and the Vercel
   preview for the website. Never use the production database for this
   work. (The public pages, step 5a, need none of this and can start now.)
3. Sign-in setup for the portal ([7.6](#76-the-website)): the Apple
   Services ID and secret, the Microsoft tenant check, the Google
   authorised domain, and the redirect URLs, on staging first.

### Step 1: Database

1. New migration `supabase/migrations/<timestamp>_school_portal.sql`:
   tables (7.3), teachers' Studafy IDs, indexes, RLS on with **no**
   policies (only the functions read them), functions (7.4), the portal
   branch of the file delivery check, grants.
2. Hook account deletion, data export and retention (7.3).
3. pgTAP test `supabase/tests/school_portal.sql`:
   - an admin sees only their own org; at most 3 admins;
   - a pending, declined, cancelled, expired or unlinked teacher's classes
     are invisible; an unlink hides everything at once;
   - all of a linked teacher's classes are visible, including one created
     after linking;
   - the roster has emails, Studafy IDs and linked parents; marks include
     unpublished and AI-suggested ones; attendance is per day; wellbeing
     notes are included;
   - messages, AI Tutor chats, personal notebooks and notes, flashcards
     and quizzes are never returned by any portal function;
   - a suspended or closed org sees nothing;
   - a portal admin has no `memberships` row and no existing staff
     function lets them in (`coursework_teacher`, `coursework_staff`,
     `is_school_admin` all false);
   - every read writes one activity row; file delivery works only for a
     linked teacher's class;
   - request rate limits, the 30-day re-ask block and expiry;
   - only teacher accounts can be found by the portal's ID lookup;
   - deletion and export include the new rows.
4. Run the tests on a **throwaway** database only (see the project's
   pgTAP notes), never the hosted one.

**Status (2026-11-05):** done on this branch, except item 1's file-delivery
branch (moved to step 2, with the download route it serves).
`supabase/migrations/202611050010_school_portal.sql` and
`supabase/tests/school_portal.sql` (66 checks, in CI after
`ai_output_reports.sql`); the worker's retention pass runs
`private.school_portal_purge`. Choices made while building:

- **The teacher's Studafy ID is `profiles.public_id`**, the 10-digit number
  every account already has and the app already shows as "Your Studafy ID".
  The portal's lookup is the first that finds anyone by it; it finds only
  teacher accounts and is counted per administrator.
- **Safeguarding-restricted wellbeing notes are not shown** to the school;
  every other wellbeing note is. Those notes are, by design, limited to the
  people the teacher chose. Change only with the owner and the lawyer.
- **Website-only administrators must be recorded as adults.** Creating a
  school checks `private.account_kind(...) = 'adult'`; a person who signs in
  on the website only has no membership, so the portal's sign-up (step 5b)
  must record `profiles.account_kind = 'adult'` (an age confirmation) first.
- The commands' idempotency records have no school (`school_id` null),
  since the administrator belongs to none.

### Step 2: API

1. Contracts (`schoolPortal.ts`), catalogue entries, permissions (7.5).
2. Routes and repository in `apps/api/src/school-portal/`.
3. The switch `SCHOOL_PORTAL_ENABLED` (default **false** everywhere,
   including `fly.api.toml` and `fly.worker.toml`).
4. CORS allow-list for the portal origin, only on portal routes.
5. Tests: route tests with fakes; an integration test against the real
   SQL; the switch-off test (every route 404s); the catalogue mounting test.
6. `bun run generate` → `bun run generate:check`.

**Status (2026-11-05):** done on this branch except the file branch (below).

- 27 routes in `V1_ROUTE_CATALOGUE` (`SchoolPortal.*` in
  `packages/contracts/src/v1/schoolPortal.ts`), served by
  `apps/api/src/school-portal/routes.ts` over `api062_query/command`.
  Whole-list reads are named `list…` (they cost 2 on the rate limiter); the
  dashboard costs 1. There is no PATCH: editing a school is
  `POST /v1/school-portal/orgs/{orgId}`. Hand-ins and test answers sit under
  the school (`…/orgs/{orgId}/assignments/{id}/hand-ins`,
  `…/orgs/{orgId}/tests/{id}/answers`), since the SQL finds the class.
- Permissions `school_portal.read|manage` and `school_link.read|manage`
  (self-scoped). New error codes: `TEACHER_NOT_FOUND`,
  `SCHOOL_ADMIN_LIMIT`, `ALREADY_ADMIN`, `SCHOOL_LINK_EXISTS`,
  `SCHOOL_LINK_RECENTLY_DECLINED`, `TEACHER_REQUESTS_FULL`,
  `LINKED_ELSEWHERE`, `SCHOOL_UNAVAILABLE`, `ALREADY_REPORTED`.
- `SCHOOL_PORTAL_ENABLED` (off; `"false"` in `fly.api.toml` and
  `fly.test.api.toml`, pinned by `scripts/fly-config.test.ts`): off, every
  portal and `/v1/me/school-links*` route answers 404 before anything else.
- `SCHOOL_PORTAL_ORIGINS`: the website's origins may call only
  `/v1/school-portal/*` and `GET /v1/me` (preflight checked against the real
  method). Read only while the switch is on.
- Turnstile on creating a school and on asking for a teacher (same
  `captchaToken` field as the student lookup; the token never reaches SQL).
  At release, add the website's host to `TURNSTILE_HOSTNAMES` and the site
  key's hostname list. Rate limits: asking for a teacher is on the
  `linking` flow, creating a school on `registration`.
- Tests: `apps/api/test/school-portal/routes.test.ts` (switch, refusals,
  shapes, contract), `schoolPortal.integration.test.ts` (real SQL end to
  end), the CORS case in `apps/api/test/platform/middleware.test.ts`, the
  catalogue mounting test. OpenAPI and the Dart client regenerated.
- **Still to do in this step:** opening files. The download intent
  (`apps/api/src/files/routes.ts`) needs a portal branch in
  `private.file051_authorize_download` (re-issued whole) that admits a live
  administrator of an active school for a file bound to a linked teacher's
  class, writes a `file` activity row, and never mints a storage-signed URL.
  Until then the portal lists files but cannot open them.
- `GET /v1/me`'s `schoolPortal` flag moves to step 4, with the app screen
  that reads it.

### Step 3: Notices (worker)

1. One new notification template key, `school_portal.link_requested`, to
   the **teacher** only (in-app and push), emitted by
   `school_portal_link_request` into the existing outbox. No notices to
   students or parents.
2. Route the tap to the request screen (the deep-link table in
   `lib/app/notification_routes.dart`).
3. An operator alert (existing Telegram relay) when a teacher reports a
   school.
4. Worker and pgTAP tests.

### Step 4: Phone app (teacher side)

1. Data: `lib/features/school_portal/data/api_school_links_repository.dart`
   and domain models.
2. Screens: `lib/features/school_portal/presentation/` (Studafy ID in
   Account, request screen, linked banner, Account → Schools, unlink,
   report) as in section 6.
3. Shown only when `schoolPortal: true`.
4. EN/AR strings; `flutter gen-l10n`.
5. Widget tests (request shows who asks and what is shared, accept,
   decline, report, banner and unlink, switch off hides everything) and a
   Dart bounds check.

### Step 5: Website

**5a. Public pages (no backend; can start now):**

1. Create `apps/school-web/` (Vite + React + TS), add it to the workspace
   and to `scripts/check-bounds.ts`, add its build and tests to CI (a job
   that runs only on this branch until the gate).
2. Shared header and footer, EN/AR with RTL, the `VITE_PORTAL_PUBLIC`
   switch.
3. Pages: `/`, `/features`, `/schools` (built only with the switch on),
   `/about`, `/contact`, prerendered to HTML; sitemap, robots, share
   images.
4. Design and motion as in [4.7](#47-design-and-motion).
5. Tests: every page renders in both languages; the switch off removes
   `/schools`, its links and every sign-in button; links and anchors
   resolve; reduced motion turns animations off; Lighthouse and an
   accessibility scan meet [4.7](#47-design-and-motion).
6. Security headers in `vercel.json`; check them with a header scanner on
   the preview URL.

**5b. Portal (needs steps 1–2 on staging):**

1. Sign-in with Apple, Google and Microsoft, then create school,
   dashboard, link a teacher, teachers, classes, class tabs, settings
   (section 5).
2. EN/AR, RTL, phone layout.
3. Tests: unit tests for data formatting; component tests for each
   screen's empty, loading, error and full states; an end-to-end test
   (Playwright) against staging with a fake school, teacher and class.

### Step 6: Operator tools

1. Suspend / restore a school (existing operator path, `/internal/...`).
2. A list of teachers' reports, and the alert from step 3.

### Step 7: Legal and docs

1. Privacy policy and terms updates (section 9), new consent version with
   SHA-256 pins, like every earlier policy change.
2. School agreement (data processing agreement) template, accepted when a
   school is created.
3. Store privacy answers: Google Play Data safety and App Store privacy
   labels say data is shared with schools a teacher accepts
   (`docs/store/google-play-data-safety.md`,
   `docs/store/app-store-privacy-labels.md`).
4. `docs/deployment/school-portal.md` (setup, switches, Vercel, the domain
   move, Supabase redirect URLs, the Apple secret renewal), decision log
   entry, ADR "School Portal: read-only school view of linked teachers'
   classes".
5. Store listing note for the app update ("Teachers can now link with
   their school").

### Step 8: Security review and staging test

1. Run `/security-review` on the branch and fix findings.
2. Full test on staging with fake schools, teachers, students and
   parents, including the "try to see another school's class" test.
3. Fix what it shows.

---

## 9. Privacy, legal and safety

### 9.1 Who is responsible for the data

Today, a teacher using Studafy on their own decides what happens with
their class's data, and Studafy processes it. When a teacher accepts a
school's request, that **school** also receives the data of all their
classes. Before any real school uses the portal:

- a **school agreement** (data processing agreement) accepted by each
  school: what they see, that they keep it confidential, that they do not
  copy it out of the portal, who to contact;
- the **Privacy Policy** gains a section "Teachers linking with a school":
  what is shared (section 9.2), that the teacher decides, that students and
  parents are not told individually, and that the school never sees
  messages, AI Tutor chats or students' own notes;
- the **Terms** gain the administrator's duties;
- the **store privacy answers** (Data safety, App Store labels) cover the
  sharing with schools;
- a short **DPIA** (data protection impact assessment) note, like the
  earlier ones;
- `TODO(legal)`: have a lawyer read all of these before the portal goes
  live.

### 9.2 What the school sees and never sees

**Sees (read-only), for every class of a linked teacher:** students'
names, emails and Studafy IDs; linked parents' names and emails; lessons
and the teacher's files; hand-ins (files, photos, typed answers) and
online-test answers; all marks, including unpublished and AI-suggested
ones; each student's daily attendance; the teacher's wellbeing notes.

**Never sees:** messages (any conversation) · students' AI Tutor chats ·
students' personal notebooks and notes · flashcards and quizzes · anything
from teachers who have not accepted or have unlinked.

### 9.3 Read-only, on purpose

No portal route writes to a class. The SQL functions for the portal have
no `insert`, `update` or `delete` on any class, coursework, mark,
attendance or note table. A pgTAP test proves it.

### 9.4 No notices to students and parents

Owner's decision (2026-11-05): students and parents are **not** notified
when their teacher links with a school. The Privacy Policy and Terms
describe the sharing instead (9.1). The lawyer's review checks that this is
enough, especially for children (9.6).

### 9.5 Risks the owner accepted

Anyone can create a school page, with no check by Studafy; a linked school
sees a wide set of data, including children's emails, their work and
wellbeing notes; and families are not told. So **the teacher's Accept is
the only safeguard.** The portal is built to make that decision informed
and reversible:

- **Who is asking:** the request shows the school's name, city, country
  and type, and the administrator's name, job title and email.
- **What is shared:** the request lists everything the school will see and
  what it never sees, before **Accept**.
- **Always visible:** while linked, a banner says "Your classes are visible
  to <school>", with **Unlink** one tap away; unlinking hides everything at
  once.
- **Rate limits:** on requests per school, ID lookups per administrator,
  pending requests per teacher, and a 30-day block after a decline.
- **Report a school:** from the request or the link; reports alert
  Studafy.
- **Audit log:** every page and file an administrator opens is recorded.
- **Suspension:** Studafy can suspend a school at once; a suspended school
  sees nothing.

### 9.6 Children

Many students are under 13 (the store age settings declare under-13s). A
linked school sees their emails, work, marks, attendance and wellbeing
notes. The lawyer's review (9.1) must cover sharing children's data with a
school without notifying the family. Any later feature that lets a school
contact children directly needs its own review first.

---

## 10. Testing

| Level | What | Where |
|---|---|---|
| Database | Access rules, what is and is never returned, read-only proof, rate limits, deletion, export, retention | `supabase/tests/school_portal.sql` |
| API | Each route, permissions, switch off → 404, CORS only for the portal origin, file delivery for portal admins | `apps/api/test/school-portal/` |
| Worker | The teacher's request notice; report alerts | `apps/worker/test/` |
| App | Studafy ID, request screen, banner, unlink, report, switch, EN/AR | `test/features/school_portal/` |
| Public pages | Both languages, the portal switch, links, reduced motion, Lighthouse and accessibility | `apps/school-web/test/` |
| Portal | Screens' states, RTL, end-to-end on staging | `apps/school-web/test/`, Playwright |
| Security | `/security-review`, CSP/header scan, a manual "try to see another school's class" test | Before the gate |

---

## 11. The release gate: when this may be merged

There are two releases: the public pages first, then the portal.

### 11.1 Public pages release

The public pages (static, no API, no database, `VITE_PORTAL_PUBLIC` off)
may be deployed **from this branch** to `studafy.com` when all of these
are true:

1. ✅ The app is **approved and live** on both the App Store and Google
   Play, so the store badges link to real pages.
2. ✅ Every claim matches the current store listing
   (`docs/store/listing-copy.md`), and the screenshots are up to date.
3. ✅ The website CI job passes (build and tests; accessibility and
   Lighthouse checks are still to add); the header scan on the preview URL
   passes.
4. ✅ The waitlist sign-ups are exported.
5. ✅ The owner says go.

Then move the domain ([4.9](#49-moving-studafycom-from-the-waitlist-site)).
This does **not** merge anything into `main`.

### 11.2 Portal gate: merging into main

**All** of these must be true before a pull request from
`feat/school-admin-web` into `main` is even opened:

1. ✅ The first app version is **approved and live** on both the App Store
   and Google Play (the Apple organization migration is finished).
2. ✅ Staging exists and the full portal has been tested there.
3. ✅ The Privacy Policy, Terms, school agreement and store privacy
   answers are written, and a lawyer has read them (`TODO(legal)`
   removed).
4. ✅ `/security-review` has been run and every finding is fixed.
5. ✅ All CI jobs pass on the branch, including the website job.
6. ✅ The owner says, in their own words, that it may be merged.

After merging, in this order:

1. Deploy the API and worker with `SCHOOL_PORTAL_ENABLED=false`.
2. Release the app update (store review) with the hidden teacher screens.
3. Publish the new Privacy Policy and Terms (`bun run legal:deploy`), and
   update the store privacy answers.
4. Add `school.studafy.com` to the `studafy-web` project, and deploy the
   website with `VITE_PORTAL_PUBLIC=true`.
5. Switch `SCHOOL_PORTAL_ENABLED=true`, for everyone at once.

---

## 12. How to keep the branch separate from `main`

### 12.1 Rules

- The branch is **`feat/school-admin-web`**. All portal and website work
  happens there or on short branches made from it and merged back into it.
- **Never** open a pull request from it into `main` until the gate
  (section 11.2). Pull requests for this work target
  `feat/school-admin-web`, not `main`.
- Nothing from this branch is deployed to production, **except** the
  public pages under [11.1](#111-public-pages-release) (static files on
  Vercel, portal switch off). Staging deploys come from this branch.
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
| later | Optional "verified school" badge | Only if schools ask for it; version 1 has no check. |

---

## 14. Owner decisions and open questions

### Decided (2026-11-05)

| Question | Decision |
|---|---|
| Where the website lives | `studafy.com` for the public pages (replacing the waitlist site), `school.studafy.com` for the portal; one Vercel project `studafy-web` |
| Public pages before the portal | Yes, once the app is live in both stores, with `/schools` and sign-in hidden until the portal's release |
| Name | Studafy School Portal |
| Administrators per school | Up to 3; the first adds the others |
| How Studafy checks a school | It does not. Anyone can create a school; nothing is visible until a teacher accepts the school's request |
| How a school links | The administrator enters the teacher's Studafy ID, like a parent with a student's; the teacher accepts or declines, and can unlink any time |
| Which classes | All of the teacher's classes, including new ones, while linked |
| What the school sees | Students with emails and Studafy IDs; linked parents with emails; lessons and files; hand-ins and test answers; all marks, including unpublished and AI-suggested; daily attendance; wellbeing notes |
| What the school never sees | Messages; students' AI Tutor chats, personal notebooks and notes, flashcards and quizzes |
| Editing | None; read-only |
| Notices to students and parents | None; the Privacy Policy and Terms cover it |
| Rollout | Everyone at once when switched on |
| Attendance | Each student's daily record |
| About page | Company voice; no team, no personal story |
| Company details on the site | None; footer "© Studafy" |
| Contact email | `hello@studafy.com` |
| Design | Polished, company-grade, with tasteful motion |
| A teacher and two schools | One school at a time; accepting a second request unlinks the first (with a warning) |
| Class announcements | Shown to the school, read-only, with the lessons |

### Still open

None. New questions found while building go here.

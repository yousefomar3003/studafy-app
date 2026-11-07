# Studafy School Agreement

**Last updated:** 6 November 2026\
**Version:** 1.0

<!--
BRANCH ONLY (feat/school-admin-web). Not published until the School
Portal's release gate (docs/planning/school-portal.md 11.2). The legal
site's build strips every HTML comment.

This is the data-sharing agreement of plan 9.1 and step 7.2: each school
administrator accepts it when they create a school's page or accept an
invitation to run one, and the portal records the version and the time for
each administrator (private.school_portal_admins.agreement_version and
agreement_accepted_at). The version accepted is the "Version" above as a
date: 2026-11-06 (SCHOOL_AGREEMENT_VERSION in
packages/contracts/src/v1/schoolPortal.ts and
private.school_portal_agreement_version()). A substantive change needs a
new version in all three places; administrators are then asked to accept
it again (TODO: the portal does not ask yet, because there is only one
version).

It was written from what the portal actually does (plan sections 7 and 9,
privacy policy 2.1 §3.13 and §7.4, terms 1.9 §15). It has NOT been
reviewed by a lawyer, and it must be before any real school uses the
portal. Questions for counsel:

TODO(legal) (1) Roles. This agreement treats Studafy and the school as
independent controllers (privacy policy §1.1 and §7.4). Confirm, or decide
whether the teacher's school is in fact the controller of the class
records already, with Studafy its processor, in which case this should be
an Article 28 processing agreement and the policy changes with it.

TODO(legal) (2) Lawful basis for the disclosure. Studafy discloses on the
strength of the teacher's acceptance alone, with no notice to families
(owner's decision, plan 9.4 and 9.6), and many students are under 13.
Clause 4.2 asks the school to have its own basis and to tell families in
its own privacy notice. Is that enough, and is it enough for children?

TODO(legal) (3) Unverified schools. Anyone can create a page (plan 9.5).
An agreement accepted by someone who does not represent a real school
binds no school. Does that change how the disclosure must be justified?

TODO(legal) (4) Incident timings in clause 9 (48 hours for the school,
"without undue delay" for Studafy) are proposals.

TODO(legal) (5) Liability (clause 12) and governing law (clause 13) follow
the Terms of Use, which counsel is also still to finish.

TODO(legal) (6) Whether clicking to accept is a valid way for a school to
enter this agreement, or whether schools must sign it.
-->

This agreement is between **Studafy Limited** ("Studafy", "we"), company
number 822430, 4/5 The Square, Cahir, Co. Tipperary, Ireland, and the
**school** named on a school's page on the Studafy School Portal (the
"school", "you"). It sets out how a school may use the personal data it
reads through the portal.

An administrator accepts it for the school, by ticking the box when they
create the school's page or accept an invitation to run it. Each
administrator who accepts confirms that they are an adult (18 or over) and
authorised to bind the school. We record which version each administrator
accepted, and when.

The [Terms of Use](terms) (in particular §15) and the
[Privacy Policy](privacy) (in particular §3.13 and §7.4) also apply. If
this agreement and the Terms differ on how a school uses portal data, this
agreement applies.

## 1. What the portal is

The Studafy School Portal (school.studafy.com) is a website where a school
reads the classes of teachers who link with it. A teacher links only by
accepting the school's request in the Studafy app, and can unlink at any
time. A teacher links with one school at a time.

The portal is **read-only**: a school cannot change a class, a mark, an
attendance record or any other record, and cannot message a student. It
can download reports, send announcements to whole classes, and make class
groups, as described below.

## 2. The data the school can read

While a teacher is linked, the school's administrators can read, for every
current class the teacher teaches:

- the class: its name, grade, section, teachers and number of students;
- the students: each one's name, email address and Studafy ID, and the
  name and email address of each linked parent;
- lessons, the teacher's lesson material and files, and the class's
  announcements;
- set work and hand-ins, including typed answers and handed-in files and
  photos, and online tests with their questions and every answer;
- every mark, including marks not yet published and marks suggested by
  AI;
- attendance;
- the teacher's wellbeing notes, except notes restricted to safeguarding;
- figures worked out from these (attendance rates, average marks, missing
  work, and which students may need attention);
- about the teacher: their name, email address, classes, recent lessons
  and the marking still to do.

The school **never** sees messages or conversations, AI Tutor chats,
students' notebooks and personal notes, notes, quizzes and flashcards made
with the AI study tools, wellbeing notes restricted to safeguarding,
subscriptions or payments, or anything from a teacher who has not accepted
or has unlinked.

This is the "**portal data**". A copy of portal data that the school
downloads, prints or writes down is "**exported data**".

## 3. Who is responsible for what

3.1 **Studafy** is responsible for the data in Studafy, for showing the
school only what this agreement allows, and only while a teacher is
linked, and for the security of the portal.

3.2 **The school** decides for itself how it uses the portal data it reads
and the exported data it keeps. For that use it is responsible as a
controller in its own right under data-protection law (in the EU and the
UK, the GDPR).

3.3 Neither party acts as the other's processor under this agreement.

## 4. How the school may use portal data

4.1 **Only for the school's purposes:** teaching, assessment, attendance,
students' welfare and safeguarding, and running the school. Never for
advertising or marketing, never sold, rented or given to anyone outside
the school, and never used to train an AI model.

4.2 **On its own lawful basis.** The school must have its own lawful basis
for reading and keeping portal data, and must tell students and parents
about it in its own privacy information, as the law requires. Studafy does
not tell students and parents one by one when their teacher links with a
school.

4.3 **Only the people who need it.** Up to three administrators run a
school's page. The school chooses them, keeps their sign-in to themselves,
removes an administrator who leaves or no longer needs access, and shares
portal data inside the school only with people who need it for the
purposes in 4.1.

4.4 **Confidentially.** Administrators keep portal data confidential, also
after they stop being administrators.

4.5 **Within the portal's limits.** No one at the school may try to see a
class or a student the portal does not show them, or get around the
portal's limits, for example by using a teacher's Studafy account or by
automated collection.

4.6 **Fairly towards teachers.** Ask only teachers who teach for the
school, and never pressure a teacher to accept or not to unlink.

## 5. Exported data

5.1 Everything the school downloads or prints is recorded (clause 8).

5.2 Exported data is outside Studafy. The school keeps it secure, shares
it only as clause 4 allows, and deletes it when it no longer needs it, or
as its own retention rules require.

5.3 When a teacher unlinks, or this agreement ends, the school stops
seeing the portal data at once. It may keep exported data only as long as
it has a lawful reason to, under its own retention rules.

## 6. Announcements and class groups

6.1 **Announcements** go to whole classes: to the students, the parents or
both, of all linked classes or the classes the school chooses, or to the
linked teachers. Never to one student alone. They carry only school
matters: nothing that singles out or identifies a student, nothing
unlawful or unsuitable for children, and no advertising. Studafy may
remove an announcement.

6.2 **Class groups** let students join several linked classes with one
code. Put together only classes that belong together, and share the code
only with the students meant to join. Each teacher decides whether their
class joins a group, and can take it out.

## 7. Children

Many students are children. The school takes particular care with their
data, does not use the portal to contact a child outside its
announcements, and follows its own safeguarding rules for anything the
portal data shows about a child's welfare.

## 8. The activity record

Every page and file an administrator opens, and every download, is
recorded with the class or student it concerned and when. We keep this
record for 12 months, and use it to keep schools accountable, to look into
reports and suspected misuse, and to answer requests from teachers,
students and families.

## 9. Security and incidents

9.1 The school keeps its administrators' sign-ins secure and its devices
and exported data protected with measures suitable for children's data.

9.2 The school tells us at hello@studafy.com, without undue delay and in
any case within 48 hours of becoming aware, if an administrator's account
may have been used by someone else, or if portal data or exported data may
have been lost, disclosed or accessed without authority. It is
responsible for any notice the law requires it to give for data it
controls.

9.3 We tell the school without undue delay if we find that portal data the
school could see was disclosed through the portal to someone not entitled
to it.

## 10. Requests from people

10.1 Students, parents and teachers can ask Studafy about the data in
Studafy (Privacy Policy §11). They ask the school about what the school
holds, including exported data.

10.2 Each party passes on, without undue delay, a request it receives that
is for the other, and gives reasonable help with it.

## 11. Suspension, ending and changes

11.1 The school can close its page at any time in the portal's settings.
When the last administrator leaves, or the page is closed, every teacher
is unlinked.

11.2 We may suspend or close a school's page, with or without notice, if
we reasonably believe this agreement or the Terms are being broken, the
page does not represent a real school, or a teacher or family is at risk.
A suspended page sees nothing.

11.3 This agreement ends when the school's page is closed. Clauses 4.4,
5, 9.2, 10 and 12 continue afterwards for exported data.

11.4 We may change this agreement. A substantive change has a new version,
and administrators are asked to accept it before they use the portal
again.

## 12. Liability

Each party is responsible for its own use of the data it controls, and for
its own breaches of data-protection law. Nothing in this agreement limits
liability that the law does not allow to be limited.

## 13. Law

This agreement is governed by the law of Ireland, and the courts of
Ireland decide disputes about it.

## 14. Contact

hello@studafy.com

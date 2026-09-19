# ADR-0027: Messaging safeguards and mobile report/block controls

- Status: Accepted for local/disposable use
- Date: 2026-09-19
- Decision owner: repository owner (GitHub `@yousefomar3003`)
- Decision log: DL-049
- Amends: ADR-0020 (API-042 communications), ADR-0021 (SAFE-043)

## Context

Building the mobile report and block controls exposed four defects in the
server messaging path that no test had caught:

1. **Private messages leaked to all staff.** `sendMessage` wrote an audience
   outbox row whose payload was the full message, body included. OPS-061
   expands a school audience into an in-app delivery for every active teacher
   and school admin, and the notifications API returns the payload. Every
   private conversation between a parent or student and a teacher would have
   been readable by all staff once the notification worker was switched on,
   and the actual recipients were never notified.
2. **No contact policy.** Any member or verified guardian of a school could
   open a conversation with any other, so a parent could message another
   family's child directly.
3. **The messaging switch was not enforced.** `school_content_controls.
   messaging_enabled` defaults to off and was displayed, but no command read
   it.
4. **Chats were paged by random UUID**, so messages rendered out of time
   order, and guardians, who have no membership row, never received a
   continuation cursor and could not load older messages.

The mobile app had no report or block control at all, which Apple guideline
1.2 and Google Play's user-generated-content policy both require.

## Decision

- **Contact policy (safeguarding default).** Staff may contact anyone in the
  school. Anyone may contact staff. A guardian and the child they hold a
  verified, unexpired link to may contact each other. Nothing else: no
  student-to-student, guardian-to-other-child or guardian-to-guardian
  conversations. It is enforced on conversation creation and again on every
  message, so a revoked link or ended membership stops contact at once. A
  school that wants student-to-student messaging needs a new, reviewed
  decision; it is not a switch.
- **Messaging stays off until a school turns it on.** Both commands return
  `MESSAGING_DISABLED` while the content control is off.
- **Notifications carry no content.** Each other participant receives one
  in-app notification whose payload is the conversation and message ids. The
  audit trail records that a message was sent, never its text. Rows written
  by the leaking path are redacted, and their non-participant deliveries
  deleted, by migration `202609190005`.
- **Keyset time order.** Messages page newest first and conversations by
  recent activity, using the existing `(conversation_id, created_at desc, id
  desc)` index. A caller without a tenant receives a cursor bound to their own
  account; the SQL re-authorizes every page.
- **Contacts directory.** `GET /v1/contacts?schoolId=` lists exactly the
  people the policy allows. Staff also see which child a guardian belongs to;
  nobody else learns about other families.
- **Mobile controls.** A new `lib/features/messaging` slice replaces the
  legacy chat screens in real builds for teachers, parents and students. Every
  conversation has a labelled menu to report the conversation, report a
  person and block a person, and every message can be reported with a long
  press. Reports can also block in the same step. A Blocked people screen
  lists only blocks the user made, each with Unblock; a block made by the
  other person is never attributed or listed. All copy ships in English and
  Arabic.

## Consequences

- Messaging becomes usable end to end in real builds, with the controls the
  stores require. It remains launch-blocked by SAFE-043's operational gate:
  named and trained moderators, an independent safety review and a response
  drill.
- Existing tests that exercise messaging now opt their school in explicitly.
- The legacy teacher inbox remains only in the synthetic demo, because its
  announcement and meeting forms have no `/v1` replacement screen yet.
- Messaging is online-only on mobile by design: a message is never shown as
  sent until the server accepted it, and a retry reuses the client message id
  so it lands exactly once.

## Evidence

- `supabase/migrations/202609190005_messaging_safeguards.sql`,
  `202609190006_messaging_keyset_order.sql`
- `apps/api/test/communications/communications.integration.test.ts`
  (switch, policy, contacts, participant-only content-free notifications,
  newest-first paging across a page boundary for a guardian)
- `test/messaging_safety_test.dart` (labelled controls, long-press report,
  block and unblock, other-party blocks hidden, idempotent retry, Arabic)

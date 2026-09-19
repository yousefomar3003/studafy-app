/**
 * DL-052 meeting processor against a real local Postgres with a fake
 * conferencing provider. The SQL lease/retry/fail state machine is covered
 * in supabase/tests/meeting_processor.sql.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createDatabase, type Sql } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import {
  calendarEventIdFor,
  type ConferenceProvider,
  ConferenceProviderError,
} from "@studafy/infrastructure";
import { startMeetingProcessor } from "../src/processors/meetings";

const databaseUrl = process.env["DATABASE_URL"];
const suite = databaseUrl ? describe : describe.skip;

const SCHOOL = "d1052000-0000-4000-8000-0000000000b1";
const TERM = "d1052000-0000-4000-8000-0000000000e1";
const CLASSROOM = "d1052000-0000-4000-8000-0000000000c1";
const TEACHER = "d1052000-0000-4000-8000-0000000000a1";
const OK_MEETING = "d1052000-0000-4000-8000-0000000000f1";
const REFUSED_MEETING = "d1052000-0000-4000-8000-0000000000f2";
const logger = createJsonLogger("worker", "test", "error", () => undefined);
let sql: Sql;

class FakeProvider implements ConferenceProvider {
  scheduled: string[] = [];
  cancelled: string[] = [];
  async schedule(input: { meetingId: string }) {
    if (input.meetingId === REFUSED_MEETING) {
      throw new ConferenceProviderError("PROVIDER_REFUSED_403", true);
    }
    this.scheduled.push(input.meetingId);
    return {
      eventId: calendarEventIdFor(input.meetingId),
      joinUrl: "https://meet.example/abc-defg-hij",
    };
  }
  async cancel(eventId: string) {
    this.cancelled.push(eventId);
  }
}

async function cleanup(): Promise<void> {
  await sql.begin(async (tx) => {
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`delete from public.notification_deliveries where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.notification_outbox where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.meeting_deliveries where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.meetings where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.audit_events where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.classrooms where id = ${CLASSROOM}::uuid`;
    await tx`delete from public.terms where id = ${TERM}::uuid`;
    await tx`delete from public.memberships where school_id = ${SCHOOL}::uuid`;
    await tx`delete from public.schools where id = ${SCHOOL}::uuid`;
    await tx`delete from auth.users where id = ${TEACHER}::uuid`;
    await tx`alter table public.audit_events enable trigger db020_reject_mutation`;
  });
}

suite("DL-052 meeting processor", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await sql`
      insert into auth.users (
        id, email, encrypted_password, aud, role, email_confirmed_at,
        created_at, updated_at, instance_id, confirmation_token,
        recovery_token, email_change, email_change_token_new,
        email_change_token_current, phone_change_token, raw_app_meta_data,
        raw_user_meta_data
      ) values (
        ${TEACHER}::uuid, 'dl052.teacher@synthetic.studafy.test', 'x',
        'authenticated', 'authenticated', now(), now(), now(),
        '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
        '{}'::jsonb, '{"full_name":"DL052 Teacher"}'::jsonb
      )
    `;
    await sql`insert into public.schools (id, name, timezone, status) values (${SCHOOL}::uuid, 'DL052 School', 'Asia/Riyadh', 'active')`;
    await sql`insert into public.memberships (school_id, user_id, role, active, status) values (${SCHOOL}::uuid, ${TEACHER}::uuid, 'teacher', true, 'active')`;
    await sql`insert into public.terms (id, school_id, name, starts_on, ends_on, active) values (${TERM}::uuid, ${SCHOOL}::uuid, 'Term', '2026-09-01', '2026-12-31', true)`;
    await sql`insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id) values (${CLASSROOM}::uuid, ${SCHOOL}::uuid, ${TERM}::uuid, 'DL052 Class', 'G6', 'A', ${TEACHER}::uuid)`;
    for (const id of [OK_MEETING, REFUSED_MEETING]) {
      await sql`
        insert into public.meetings (id, school_id, classroom_id, title, starts_at, ends_at, audience, state, created_by)
        values (${id}::uuid, ${SCHOOL}::uuid, ${CLASSROOM}::uuid, 'Parent evening',
          now() + interval '3 days', now() + interval '3 days 1 hour', 'guardians', 'pending', ${TEACHER}::uuid)
      `;
      await sql`
        insert into public.meeting_deliveries (school_id, meeting_id, recipient_id, state)
        values (${SCHOOL}::uuid, ${id}::uuid, ${TEACHER}::uuid, 'queued')
      `;
    }
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("event ids use only Google Calendar's base32hex alphabet", () => {
    expect(calendarEventIdFor(OK_MEETING)).toMatch(/^[a-v0-9]{5,1024}$/);
  });

  test("schedules a meeting, fails a refused one, then withdraws on cancel", async () => {
    const provider = new FakeProvider();
    const runtime = startMeetingProcessor(sql, provider, logger, 3_600_000);
    try {
      await runtime.runOnce();
      const rows = await sql<
        { id: string; state: string; meet_url: string | null }[]
      >`
        select id, state, meet_url from public.meetings
        where school_id = ${SCHOOL}::uuid order by id
      `;
      expect(rows.find((r) => r.id === OK_MEETING)?.state).toBe("scheduled");
      expect(rows.find((r) => r.id === OK_MEETING)?.meet_url)
        .toBe("https://meet.example/abc-defg-hij");
      expect(rows.find((r) => r.id === REFUSED_MEETING)?.state).toBe("failed");

      await sql`
        update public.meetings set state = 'cancelled', next_attempt_at = now()
        where id = ${OK_MEETING}::uuid
      `;
      await runtime.runOnce();
      expect(provider.cancelled).toEqual([calendarEventIdFor(OK_MEETING)]);
      await runtime.runOnce();
      expect(provider.cancelled).toHaveLength(1);
    } finally {
      await runtime.close();
    }
  });
});

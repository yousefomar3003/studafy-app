/**
 * Exercises AuthContextRepository against a real Postgres.
 *
 * The route tests use an in-memory fake, which proves the handlers but not the
 * SQL calls: a wrong parameter type or a mis-cast uuid would pass there and
 * fail in production. This file closes that gap by running the actual
 * statements against the disposable local stack.
 *
 * Skipped when DATABASE_URL is absent, matching the packages/database smoke.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { createDatabase, type Sql } from "@studafy/database";
import { AuthContextRepository, evaluateSession } from "../../src/auth/context";
import type { VerifiedToken } from "../../src/auth/verify";
import { integrationSuite, removeFixtures } from "@studafy/test-support";

const databaseUrl = process.env["DATABASE_URL"];
const suite = integrationSuite(describe);

const USER = "3f000000-0000-4000-8000-0000000000a1";
const OTHER_USER = "3f000000-0000-4000-8000-0000000000a2";
const SCHOOL = "3f000000-0000-4000-8000-0000000000b1";
const SESSION = "3f000000-0000-4000-8000-0000000000c1";
/** The failed sign-in recorded below, which has no account to hang from. */
const SIGN_IN_REQUEST = "3f000000-0000-4000-8000-0000000000d1";

let sql: Sql;
let repository: AuthContextRepository;

async function seed(): Promise<void> {
  await sql`
    insert into auth.users (
      id, email, encrypted_password, aud, role, email_confirmed_at,
      created_at, updated_at, instance_id, confirmation_token, recovery_token,
      email_change, email_change_token_new, email_change_token_current,
      phone_change_token, raw_app_meta_data, raw_user_meta_data
    )
    select
      unnest(array[${USER}::uuid, ${OTHER_USER}::uuid]),
      unnest(array[
        'auth030.integration.a@synthetic.studafy.test',
        'auth030.integration.b@synthetic.studafy.test'
      ]),
      'synthetic-not-a-secret', 'authenticated', 'authenticated', now(),
      now(), now(), '00000000-0000-0000-0000-000000000000',
      '', '', '', '', '', '', '{}'::jsonb,
      '{"full_name":"AUTH-030 Integration"}'::jsonb
    on conflict (id) do nothing
  `;
  // Schools default to 'provisioning'; auth_context() only resolves
  // memberships of an active school, so the fixture has to activate it.
  await sql`
    insert into public.schools (id, name, timezone, status)
    values (
      ${SCHOOL}::uuid, 'AUTH-030 Integration School', 'Asia/Riyadh', 'active'
    )
    on conflict (id) do update set status = 'active'
  `;
  await sql`
    insert into public.memberships (school_id, user_id, role, active)
    values (${SCHOOL}::uuid, ${USER}::uuid, 'teacher', true)
    on conflict (school_id, user_id, role) do nothing
  `;
}

/**
 * Removes only what is removable.
 *
 * `audit_events` and `auth_security_events` are append-only by design and are
 * left in place; the fixture rows are synthetic and the local database is
 * disposable. `audit_events.actor_id` is a foreign key with ON DELETE SET
 * NULL, and that null-out is an UPDATE the append-only trigger refuses, so
 * the profile rows this fixture created cannot be deleted once an audit event
 * references them. The fixture is therefore identified by fixed uuids and
 * reused rather than recreated.
 */
async function cleanup(): Promise<void> {
  await removeFixtures(sql, {
    schoolIds: [SCHOOL],
    userIds: [USER, OTHER_USER],
    requestIds: [SIGN_IN_REQUEST],
  });
}

function tokenFor(issuedAtSeconds: number): VerifiedToken {
  return {
    subject: USER,
    sessionId: SESSION,
    issuedAt: issuedAtSeconds,
    expiresAt: issuedAtSeconds + 3600,
    assuranceLevel: "aal1",
    authMethods: [],
    claims: {},
  };
}

suite("AuthContextRepository against Postgres", () => {
  beforeAll(async () => {
    sql = createDatabase(databaseUrl!);
    await cleanup();
    await seed();
    repository = new AuthContextRepository(sql);
  });

  afterAll(async () => {
    if (!sql) return;
    await cleanup();
    await sql.end({ timeout: 5 });
  });

  test("the context reflects the database, not the caller", async () => {
    const context = await repository.load(USER);
    expect(context).not.toBeNull();
    expect(context!.userId).toBe(USER);
    expect(context!.memberships).toHaveLength(1);
    expect(context!.memberships[0]!.role).toBe("teacher");
    expect(context!.memberships[0]!.school_id).toBe(SCHOOL);
    expect(context!.membershipVersion).not.toBe("none");
  });

  test("a user with no profile resolves no context", async () => {
    const context = await repository.load(
      "3f000000-0000-4000-8000-0000000000ff",
    );
    expect(context).toBeNull();
  });

  test("the claim does not leak between transactions on a pooled connection", async () => {
    // A pooled connection that kept `request.jwt.claim.sub` would serve one
    // user's data to the next request. `set_local` is what prevents it.
    const first = await repository.load(USER);
    const second = await repository.load(OTHER_USER);
    expect(first!.userId).toBe(USER);
    expect(second!.userId).toBe(OTHER_USER);
    expect(second!.memberships).toHaveLength(0);
  });

  test("devices register, list, and revoke for their owner only", async () => {
    const hash = "d".repeat(64);
    const registered = await repository.touchDevice(USER, {
      deviceHash: hash,
      platform: "ios",
      appVersion: "1.0.0+1",
      label: "Integration iPad",
    });
    expect(registered?.id).toBeString();

    const devices = await repository.listDevices(USER);
    expect(devices).toHaveLength(1);

    // The other user knows the id and still cannot revoke it.
    expect(await repository.revokeDevice(OTHER_USER, registered!.id)).toBe(
      false,
    );
    expect(await repository.revokeDevice(USER, registered!.id)).toBe(true);
    expect(await repository.revokeDevice(USER, registered!.id)).toBe(false);
  });

  test("sign out everywhere writes a watermark that denies an older token", async () => {
    const watermark = await repository.signOutAll(USER);
    expect(watermark).toBeString();

    const context = await repository.load(USER);
    const issuedBefore = Math.floor(Date.parse(watermark!) / 1000) - 60;
    const decision = evaluateSession(tokenFor(issuedBefore), context, 0);
    expect(decision.allowed).toBe(false);

    const issuedAfter = Math.floor(Date.parse(watermark!) / 1000) + 60;
    expect(evaluateSession(tokenFor(issuedAfter), context, 0).allowed).toBe(
      true,
    );
  });

  test("a reauth grant is single use and session bound", async () => {
    const grantHash = "a".repeat(64);
    const expiry = await repository.issueReauthGrant(USER, {
      purpose: "account_deletion",
      grantHash,
      sessionId: SESSION,
      assuranceLevel: "aal1",
      ttlSeconds: 300,
    });
    expect(expiry).toBeString();

    const wrongSession = await repository.consumeReauthGrant(USER, {
      purpose: "account_deletion",
      grantHash,
      sessionId: "3f000000-0000-4000-8000-0000000000c9",
      requestId: crypto.randomUUID(),
    });
    expect(wrongSession).toBe(false);

    const consumed = await repository.consumeReauthGrant(USER, {
      purpose: "account_deletion",
      grantHash,
      sessionId: SESSION,
      requestId: crypto.randomUUID(),
    });
    expect(consumed).toBe(true);

    const replay = await repository.consumeReauthGrant(USER, {
      purpose: "account_deletion",
      grantHash,
      sessionId: SESSION,
      requestId: crypto.randomUUID(),
    });
    expect(replay).toBe(false);
  });

  test("identity linking detects a cross-profile collision", async () => {
    expect(await repository.linkIdentity(USER, "google", "subject-1", true))
      .toBe("linked");
    expect(await repository.linkIdentity(USER, "google", "subject-1", false))
      .toBe("already_linked");
    expect(
      await repository.linkIdentity(OTHER_USER, "google", "subject-1", false),
    ).toBe("collision");
  });

  test("deletion request, cancel, and re-request all work", async () => {
    const impact = await repository.deletionImpact(USER);
    expect(impact).not.toBeNull();

    const first = await repository.requestDeletion(
      USER,
      "privacy_concern",
      impact,
      14,
    );
    expect(first?.created).toBe(true);

    const repeated = await repository.requestDeletion(
      USER,
      "privacy_concern",
      impact,
      14,
    );
    expect(repeated?.created).toBe(false);

    expect(await repository.cancelDeletion(USER)).toBe(true);

    // The DB-020 unique(user_id, state) constraint made this impossible.
    const again = await repository.requestDeletion(
      USER,
      "changing_schools",
      impact,
      14,
    );
    expect(again?.created).toBe(true);
  });

  test("a security event stores a hash, never the raw identifier", async () => {
    const email = "auth030.integration.a@synthetic.studafy.test";
    await repository.recordEvent({
      subject: null,
      eventType: "sign_in_failed",
      outcome: "denied",
      reasonCode: "invalid_credentials",
      accountIdentifier: email,
      ip: "203.0.113.10",
      userAgentFamily: "flutter",
      requestId: SIGN_IN_REQUEST,
    });

    const rows = await sql<{ account_hash: string; ip_hash: string }[]>`
      select account_hash, ip_hash
      from public.auth_security_events
      where event_type = 'sign_in_failed'
      order by id desc
      limit 1
    `;
    expect(rows[0]!.account_hash).toMatch(/^[0-9a-f]{64}$/);
    expect(rows[0]!.account_hash).not.toContain("@");
    expect(rows[0]!.ip_hash).not.toBe("203.0.113.10");
    // The relation is append-only, and proving the row cannot be removed is
    // part of what this suite asserts; only the teardown lifts that guard.
  });

  test("a recorded security event cannot be altered or removed", async () => {
    // Awaited explicitly rather than through expect().rejects: the rejected
    // postgres.js query has to settle before the pooled connection is reused,
    // and the matcher form leaves it unsettled.
    const attempt = async (run: () => Promise<unknown>): Promise<string> => {
      try {
        await run();
        return "allowed";
      } catch (error) {
        return error instanceof Error ? error.message : String(error);
      }
    };

    expect(
      await attempt(() =>
        sql`update public.auth_security_events set reason_code = 'tampered'`
      ),
    ).toMatch(/Append-only/);
    expect(
      await attempt(() => sql`delete from public.auth_security_events`),
    ).toMatch(/Append-only/);
  });

  // First sign-in in the development split. The signup trigger is what builds
  // the profile, so this is proved against the real database rather than the
  // fake: a wrong column or a skipped trigger would pass there and fail here.
  test("provisionIdentity creates a usable, membership-less profile", async () => {
    // Fresh per run. Nothing below writes an audit row, so the auth.users row
    // stays deletable and the cascade takes the profile with it.
    const subject = crypto.randomUUID();
    const token: VerifiedToken = {
      subject,
      sessionId: SESSION,
      issuedAt: Math.floor(Date.now() / 1000),
      expiresAt: Math.floor(Date.now() / 1000) + 3600,
      assuranceLevel: "aal1",
      authMethods: [],
      claims: {
        email: "provisioned@synthetic.studafy.test",
        user_metadata: { full_name: "First Sign In" },
      },
    };
    try {
      expect(await repository.load(subject)).toBeNull();

      await repository.provisionIdentity(token);
      const context = await repository.load(subject);
      expect(context?.userId).toBe(subject);
      expect(context?.displayName).toBe("First Sign In");
      expect(context?.profileStatus).toBe("active");
      // A profile is not school access.
      expect(context?.memberships).toEqual([]);
      expect(evaluateSession(token, context, 0).allowed).toBe(true);

      // A second sign-in leaves the existing row alone.
      await repository.provisionIdentity(token);
      const count = await sql<{ n: number }[]>`
        select count(*)::int as n from public.profiles where id = ${subject}::uuid
      `;
      expect(count[0]?.n).toBe(1);
    } finally {
      await sql`delete from auth.users where id = ${subject}::uuid`;
    }
  });
});

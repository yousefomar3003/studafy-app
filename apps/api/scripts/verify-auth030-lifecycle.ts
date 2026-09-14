/**
 * AUTH-030 end-to-end lifecycle verification against the disposable local
 * Supabase stack.
 *
 * Nothing here is mocked. Tokens are minted by the local GoTrue, verified
 * against its published JWKS, and every database call goes through the
 * least-privilege `studafy_api_runtime` role over a real connection.
 *
 * Usage:
 *   bunx supabase start
 *   bun run test:auth030:lifecycle
 *
 * It lives inside apps/api rather than the repository root because it imports
 * workspace packages. Bun links those per workspace, not into the root
 * node_modules, so a root-level script cannot resolve them on a clean install.
 *
 * Local only. It refuses to run against anything but a loopback Supabase URL,
 * because it creates users and deletes data.
 */
import { createDatabase } from "@studafy/database";
import { createJsonLogger } from "@studafy/observability";
import { authIssuer, authJwksUrl } from "@studafy/config";
import { createApp } from "../src/bootstrap/app";
import { AuthContextRepository } from "../src/auth/context";
import { JwksKeySource } from "../src/auth/jwks";
import { createAuthRoutes } from "../src/auth/routes";
import { PostgresIdempotencyRepository } from "../src/platform/idempotency";

const SUPABASE_URL = process.env["SUPABASE_URL"] ??
  "http://127.0.0.1:54321";
const ADMIN_URL = process.env["DATABASE_URL"] ??
  "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
const SERVICE_KEY = process.env["SUPABASE_SECRET_KEY"] ?? "";
const PUBLISHABLE_KEY = process.env["SUPABASE_PUBLISHABLE_KEY"] ?? "";

if (!/^https?:\/\/(127\.0\.0\.1|localhost)(:|\/)/.test(SUPABASE_URL)) {
  throw new Error(
    `Refusing to run against a non-local Supabase URL: ${SUPABASE_URL}`,
  );
}
if (!SERVICE_KEY || !PUBLISHABLE_KEY) {
  throw new Error(
    "Set SUPABASE_SECRET_KEY and SUPABASE_PUBLISHABLE_KEY from `bunx supabase status`.",
  );
}

const SCHOOL = "4a000000-0000-4000-8000-0000000000b1";
const PASSWORD = "synthetic-not-a-secret-1";
const TEACHER_EMAIL = "auth030.teacher@synthetic.studafy.test";
const ADMIN_EMAIL = "auth030.admin@synthetic.studafy.test";

const results: {
  check: string;
  expected: string;
  actual: string;
  pass: boolean;
}[] = [];

function record(
  check: string,
  expected: string,
  actual: string,
): void {
  const pass = expected === actual;
  results.push({ check, expected, actual, pass });
  const mark = pass ? "PASS" : "FAIL";
  console.log(
    `${mark}  ${check}\n        expected ${expected} · got ${actual}`,
  );
}

async function createUser(
  email: string,
  appMetadata: Record<string, unknown> = {},
): Promise<string> {
  const response = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      apikey: SERVICE_KEY,
      authorization: `Bearer ${SERVICE_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      email,
      password: PASSWORD,
      email_confirm: true,
      app_metadata: appMetadata,
    }),
  });
  const body = await response.json() as { id?: string; msg?: string };
  if (body.id) return body.id;

  // Already present from a previous run: look it up instead of failing.
  const list = await fetch(
    `${SUPABASE_URL}/auth/v1/admin/users?page=1&per_page=200`,
    {
      headers: { apikey: SERVICE_KEY, authorization: `Bearer ${SERVICE_KEY}` },
    },
  );
  const users = await list.json() as { users: { id: string; email: string }[] };
  const found = users.users.find((user) => user.email === email);
  if (!found) throw new Error(`Could not create or find ${email}`);
  return found.id;
}

async function signIn(email: string): Promise<string> {
  const response = await fetch(
    `${SUPABASE_URL}/auth/v1/token?grant_type=password`,
    {
      method: "POST",
      headers: { apikey: PUBLISHABLE_KEY, "content-type": "application/json" },
      body: JSON.stringify({ email, password: PASSWORD }),
    },
  );
  const body = await response.json() as { access_token?: string };
  if (!body.access_token) {
    throw new Error(`Sign-in failed for ${email}: ${JSON.stringify(body)}`);
  }
  return body.access_token;
}

const admin = createDatabase(ADMIN_URL);

async function main(): Promise<void> {
  console.log(`AUTH-030 lifecycle verification — ${new Date().toISOString()}`);
  console.log(`Supabase: ${SUPABASE_URL}\n`);

  // ---------------------------------------------------------------------
  // Fixture. The admin user is given app_metadata claiming school_admin so
  // the "role metadata is never trusted" check runs against a token a real
  // provider actually issued, not a hand-built one.
  // ---------------------------------------------------------------------
  const teacherId = await createUser(TEACHER_EMAIL);
  const adminId = await createUser(ADMIN_EMAIL, {
    role: "school_admin",
    roles: ["school_admin"],
    school_id: SCHOOL,
  });

  await admin`
    insert into public.schools (id, name, timezone, status)
    values (${SCHOOL}::uuid, 'AUTH-030 Verification School', 'Asia/Riyadh', 'active')
    on conflict (id) do update set status = 'active'
  `;
  await admin`
    insert into public.memberships (school_id, user_id, role, active)
    values (${SCHOOL}::uuid, ${teacherId}::uuid, 'teacher', true)
    on conflict (school_id, user_id, role) do nothing
  `;
  // The admin-claiming user is deliberately given no membership at all.
  await admin`
    delete from public.memberships where user_id = ${adminId}::uuid
  `;
  await admin`
    delete from public.auth_session_revocations
    where user_id in (${teacherId}::uuid, ${adminId}::uuid)
  `;
  await admin`
    delete from public.account_deletion_requests
    where user_id in (${teacherId}::uuid, ${adminId}::uuid)
  `;
  await admin`
    delete from public.idempotency_records
    where actor_id in (${teacherId}::uuid, ${adminId}::uuid)
  `;

  // ---------------------------------------------------------------------
  // Provision the least-privilege runtime role with a throwaway local
  // password, then connect as it. Proves the API works with only the
  // reviewed function grants, not as a superuser.
  // ---------------------------------------------------------------------
  const runtimePassword = crypto.randomUUID();
  await admin.unsafe(
    `alter role studafy_api_runtime login password '${runtimePassword}'`,
  );
  const runtimeUrl = new URL(ADMIN_URL);
  runtimeUrl.username = "studafy_api_runtime";
  runtimeUrl.password = runtimePassword;
  const runtimeSql = createDatabase(runtimeUrl.toString(), {
    max: 3,
    idleTimeout: 5,
    connectTimeout: 5,
  });

  const app = createApp({
    info: {
      service: "api",
      version: "auth030-verify",
      environment: "development",
    },
    logger: createJsonLogger("api", "auth030-verify", "warn"),
    checks: {},
    auth: createAuthRoutes(
      {
        keys: new JwksKeySource(authJwksUrl(SUPABASE_URL)),
        repository: new AuthContextRepository(runtimeSql as never),
        logger: createJsonLogger("api", "auth030-verify", "warn"),
        issuer: authIssuer(SUPABASE_URL),
        audience: "authenticated",
        clockSkewSeconds: 30,
        revocationBudgetSeconds: 0,
        reauthTtlSeconds: 300,
        deletionGraceDays: 14,
      },
      undefined,
      {
        logger: createJsonLogger("api", "auth030-verify", "warn"),
        repository: new PostgresIdempotencyRepository(runtimeSql as never),
      },
    ),
  });

  const call = (
    path: string,
    init: { method?: string; token?: string; reauth?: string; body?: unknown } =
      {},
  ) => {
    const headers = new Headers();
    if (init.token) headers.set("authorization", `Bearer ${init.token}`);
    if (init.reauth) headers.set("x-studafy-reauth", init.reauth);
    if (init.body !== undefined) {
      headers.set("content-type", "application/json");
    }
    if (init.method === "POST" && path !== "/v1/auth/reauth/verify") {
      headers.set("idempotency-key", crypto.randomUUID());
    }
    return app.request(path, {
      method: init.method ?? "GET",
      headers,
      ...(init.body !== undefined ? { body: JSON.stringify(init.body) } : {}),
    });
  };

  // ---------------------------------------------------------------------
  // 1. Unauthenticated access
  // ---------------------------------------------------------------------
  const anonymous = await call("/v1/me");
  record("anonymous request is refused", "401", String(anonymous.status));

  const garbage = await call("/v1/me", { token: "not.a.real.token" });
  record("malformed token is refused", "401", String(garbage.status));

  const anonymousBody = await anonymous.text();
  const garbageBody = await garbage.text();
  record(
    "both refusals are byte-identical apart from the request id",
    "identical",
    anonymousBody.replace(/"requestId":"[^"]+"/, "") ===
        garbageBody.replace(/"requestId":"[^"]+"/, "")
      ? "identical"
      : "different",
  );

  // ---------------------------------------------------------------------
  // 2. A real provider token
  // ---------------------------------------------------------------------
  const teacherToken = await signIn(TEACHER_EMAIL);
  const header = JSON.parse(
    atob(teacherToken.split(".")[0]!.replace(/-/g, "+").replace(/_/g, "/")),
  ) as { alg: string };
  record("GoTrue signs access tokens asymmetrically", "ES256", header.alg);

  const me = await call("/v1/me", { token: teacherToken });
  record("a real provider token is accepted", "200", String(me.status));
  const meBody = await me.json() as {
    memberships: { role: string; schoolId: string }[];
  };
  record(
    "memberships come from the database",
    "teacher",
    meBody.memberships[0]?.role ?? "none",
  );

  // ---------------------------------------------------------------------
  // 3. Role metadata in a genuine provider token is not trusted
  // ---------------------------------------------------------------------
  const adminToken = await signIn(ADMIN_EMAIL);
  const adminClaims = JSON.parse(
    atob(adminToken.split(".")[1]!.replace(/-/g, "+").replace(/_/g, "/")),
  ) as { app_metadata?: Record<string, unknown> };
  record(
    "the provider token really does claim school_admin",
    "school_admin",
    String(adminClaims.app_metadata?.["role"] ?? "absent"),
  );

  const adminContext = await call("/v1/auth/context", { token: adminToken });
  const adminBody = await adminContext.json() as {
    memberships: unknown[];
    mfaRequired: boolean;
  };
  record(
    "a token claiming school_admin receives no memberships",
    "0",
    String(adminBody.memberships.length),
  );
  record(
    "a token claiming school_admin triggers no admin policy",
    "false",
    String(adminBody.mfaRequired),
  );

  // ---------------------------------------------------------------------
  // 4. Recent authentication
  // ---------------------------------------------------------------------
  const noGrant = await call("/v1/account/deletion-request", {
    method: "POST",
    token: teacherToken,
    body: { reasonCode: "undisclosed", confirmation: "DELETE" },
  });
  record(
    "a privileged command without a grant is refused",
    "401",
    String(noGrant.status),
  );

  const verified = await call("/v1/auth/reauth/verify", {
    method: "POST",
    token: teacherToken,
    body: { purpose: "account_deletion" },
  });
  const grant = (await verified.json() as { grant: string }).grant;
  record("a reauth grant is issued", "true", String(grant.length >= 43));

  const stored = await admin<{ grant_hash: string }[]>`
    select grant_hash from public.auth_reauth_grants
    where user_id = ${teacherId}::uuid and consumed_at is null
  `;
  record(
    "only the digest of the grant is stored",
    "true",
    String(stored.every((row) => row.grant_hash !== grant)),
  );

  const withGrant = await call("/v1/account/deletion-request", {
    method: "POST",
    token: teacherToken,
    reauth: grant,
    body: { reasonCode: "undisclosed", confirmation: "DELETE" },
  });
  record("the grant authorizes the command", "200", String(withGrant.status));

  const replayed = await call("/v1/account/deletion-request", {
    method: "POST",
    token: teacherToken,
    reauth: grant,
    body: { reasonCode: "undisclosed", confirmation: "DELETE" },
  });
  record("the grant cannot be replayed", "401", String(replayed.status));

  // ---------------------------------------------------------------------
  // 5. Deletion cancel and re-request
  // ---------------------------------------------------------------------
  const cancelled = await call("/v1/account/deletion-cancel", {
    method: "POST",
    token: teacherToken,
    body: {},
  });
  record(
    "deletion is cancellable in app",
    "true",
    String((await cancelled.json() as { cancelled: boolean }).cancelled),
  );

  const secondGrant = (await (await call("/v1/auth/reauth/verify", {
    method: "POST",
    token: teacherToken,
    body: { purpose: "account_deletion" },
  })).json() as { grant: string }).grant;
  const reRequested = await call("/v1/account/deletion-request", {
    method: "POST",
    token: teacherToken,
    reauth: secondGrant,
    body: { reasonCode: "changing_schools", confirmation: "DELETE" },
  });
  record(
    "a cancelled user can request deletion again",
    "true",
    String((await reRequested.json() as { created: boolean }).created),
  );
  await call("/v1/account/deletion-cancel", {
    method: "POST",
    token: teacherToken,
    body: {},
  });

  // ---------------------------------------------------------------------
  // 6. All-device sign-out revokes an unexpired token
  // ---------------------------------------------------------------------
  const beforeSignOut = await call("/v1/me", { token: teacherToken });
  record(
    "the session works before signing out everywhere",
    "200",
    String(beforeSignOut.status),
  );

  const signOut = await call("/v1/auth/sign-out", {
    method: "POST",
    token: teacherToken,
    body: { scope: "all" },
  });
  record("sign out everywhere succeeds", "200", String(signOut.status));

  const afterSignOut = await call("/v1/me", { token: teacherToken });
  record(
    "the same unexpired token is refused on the next request",
    "401",
    String(afterSignOut.status),
  );

  const claims = JSON.parse(
    atob(teacherToken.split(".")[1]!.replace(/-/g, "+").replace(/_/g, "/")),
  ) as { exp: number };
  record(
    "and it was refused well before its own expiry",
    "true",
    String(claims.exp > Math.floor(Date.now() / 1000)),
  );

  // ---------------------------------------------------------------------
  // 7. Security events recorded without personal data
  // ---------------------------------------------------------------------
  const events = await admin<
    { event_type: string; account_hash: string | null }[]
  >`
    select event_type, account_hash
    from public.auth_security_events
    order by id desc limit 50
  `;
  record(
    "the lifecycle produced security events",
    "true",
    String(events.length > 0),
  );
  record(
    "no security event stores an email address",
    "true",
    String(events.every((event) => !(event.account_hash ?? "").includes("@"))),
  );

  // ---------------------------------------------------------------------
  // 8. PKCE and state enforcement, against the real provider
  //
  // The client-side guard checks only that a callback points at a target this
  // app claims; `state` and the code verifier are enforced by GoTrue. These
  // checks exercise that enforcement directly rather than re-asserting a
  // copy of it in a unit test.
  // ---------------------------------------------------------------------
  const exchange = (body: Record<string, unknown>) =>
    fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=pkce`, {
      method: "POST",
      headers: {
        apikey: PUBLISHABLE_KEY,
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
    });

  const stolenCode = await exchange({
    auth_code: "attacker-supplied-authorization-code",
    code_verifier: "an-attacker-chosen-verifier-value-0123456789",
  });
  record(
    "an authorization code cannot be exchanged without the real verifier",
    "true",
    String(stolenCode.status >= 400),
  );

  const noVerifier = await exchange({
    auth_code: "attacker-supplied-authorization-code",
  });
  record(
    "an authorization code cannot be exchanged with no verifier at all",
    "true",
    String(noVerifier.status >= 400),
  );

  // A redirect target outside the configured allowlist must not be honoured,
  // which is what stops a hijacked callback being sent somewhere else.
  const hostileRedirect = await fetch(
    `${SUPABASE_URL}/auth/v1/authorize?provider=google&redirect_to=${
      encodeURIComponent("https://evil.test/steal")
    }`,
    { headers: { apikey: PUBLISHABLE_KEY }, redirect: "manual" },
  );
  const redirectLocation = hostileRedirect.headers.get("location") ?? "";
  record(
    "an unlisted redirect target is not honoured",
    "true",
    String(!redirectLocation.includes("evil.test")),
  );

  // ---------------------------------------------------------------------
  // 9. The runtime role really is least privilege
  // ---------------------------------------------------------------------
  let directRead = "denied";
  try {
    await runtimeSql`select count(*) from public.profiles`;
    directRead = "allowed";
  } catch {
    directRead = "denied";
  }
  record(
    "the API's database role cannot read tables directly",
    "denied",
    directRead,
  );

  await runtimeSql.end({ timeout: 5 });
  // Leave the role unable to connect again once verification is over.
  await admin.unsafe(`alter role studafy_api_runtime password null`);
  await admin.end({ timeout: 5 });

  const failed = results.filter((result) => !result.pass);
  console.log(
    `\n${results.length - failed.length}/${results.length} checks passed`,
  );
  if (failed.length > 0) {
    console.error(`FAILED: ${failed.map((f) => f.check).join("; ")}`);
    process.exit(1);
  }
}

await main();

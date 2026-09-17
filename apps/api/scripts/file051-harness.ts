/**
 * Shared FILE-051 local verification harness.
 *
 * Wires the real file routes, the real Postgres repositories connected as the
 * least-privilege `studafy_api_runtime` role, the real scan and cleanup
 * workers connected as `studafy_worker_runtime`, and real local Supabase
 * Storage. Only authentication is replaced: the harness loads the actor's
 * session context from the database, exactly as the auth middleware does
 * after verifying a token. Local disposable stack only.
 */
import { Hono } from "hono";
import { createDatabase, type Sql } from "@studafy/database";
import {
  FileSecurityScanner,
  SupabasePrivateFileStorage,
} from "@studafy/infrastructure";
import { createJsonLogger } from "@studafy/observability";
import { AuthContextRepository } from "../src/auth/context";
import type { Actor } from "../src/auth/middleware";
import {
  type AuthorizationEnv,
  createAuthorizationDependencies,
} from "../src/authorization/middleware";
import { PostgresAuthorizationRepository } from "../src/authorization/repository";
import { PostgresFileRepository } from "../src/files/repository";
import { createFileRoutes } from "../src/files/routes";
import { PostgresIdempotencyRepository } from "../src/platform/idempotency";
import {
  requestContext,
  secureResponseHeaders,
} from "../src/platform/middleware";
import { startFileCleanup } from "../../worker/src/processors/fileCleanup";
import {
  createFileScanProcessor,
  postgresScanQueue,
} from "../../worker/src/processors/fileScan";

export const IDS = {
  school: "f051e000-0000-4000-8000-000000000001",
  otherSchool: "f051e000-0000-4000-8000-000000000002",
  teacher: "f051e000-0000-4000-8000-000000000011",
  student: "f051e000-0000-4000-8000-000000000012",
  unenrolled: "f051e000-0000-4000-8000-000000000013",
  otherTeacher: "f051e000-0000-4000-8000-000000000014",
  operator: "f051e000-0000-4000-8000-000000000015",
  term: "f051e000-0000-4000-8000-000000000021",
  classroom: "f051e000-0000-4000-8000-000000000022",
  studentRecord: "f051e000-0000-4000-8000-000000000023",
  unenrolledRecord: "f051e000-0000-4000-8000-000000000024",
} as const;

const USERS: [string, string][] = [
  [IDS.teacher, "teacher"],
  [IDS.student, "student"],
  [IDS.unenrolled, "unenrolled"],
  [IDS.otherTeacher, "other"],
  [IDS.operator, "operator"],
];

export interface Check {
  check: string;
  expected: unknown;
  actual: unknown;
  pass: boolean;
}

export async function localSupabase(): Promise<{
  apiUrl: string;
  serviceKey: string;
  dbUrl: string;
}> {
  const status = Bun.spawnSync([
    `${import.meta.dir}/../../../node_modules/.bin/supabase`,
    "status",
    "--output",
    "json",
  ], { cwd: `${import.meta.dir}/../../..`, stdout: "pipe", stderr: "pipe" });
  if (status.exitCode !== 0) throw new Error("local Supabase is unavailable");
  const local = JSON.parse(status.stdout.toString()) as Record<string, string>;
  const apiUrl = local.API_URL ?? "";
  const dbUrl = local.DB_URL ?? "";
  const serviceKey = local.SERVICE_ROLE_KEY ?? "";
  if (
    !apiUrl.startsWith("http://127.0.0.1:") ||
    !dbUrl.startsWith("postgresql://postgres:postgres@127.0.0.1:") ||
    !serviceKey
  ) {
    throw new Error(
      "refusing to run FILE-051 verification outside local Supabase",
    );
  }
  return { apiUrl, serviceKey, dbUrl };
}

export async function openHarness() {
  const local = await localSupabase();
  const admin = createDatabase(local.dbUrl, { max: 2 });
  const logger = createJsonLogger("api", "file051-verify", "warn");
  const results: Check[] = [];
  const record = (check: string, expected: unknown, actual: unknown) => {
    const pass = JSON.stringify(expected) === JSON.stringify(actual);
    results.push({ check, expected, actual, pass });
    console.log(
      `${pass ? "PASS" : "FAIL"}  ${check}${
        pass
          ? ""
          : ` (expected ${JSON.stringify(expected)}, got ${
            JSON.stringify(actual)
          })`
      }`,
    );
  };

  const storage = new SupabasePrivateFileStorage(
    local.apiUrl,
    local.serviceKey,
  );
  await cleanup(admin, storage);
  await seed(admin);

  // Throwaway local passwords for the two runtime roles; revoked on close.
  const apiPassword = crypto.randomUUID();
  const workerPassword = crypto.randomUUID();
  await admin.unsafe(
    `alter role studafy_api_runtime login password '${apiPassword}'`,
  );
  await admin.unsafe(
    `alter role studafy_worker_runtime login password '${workerPassword}'`,
  );
  const runtimeUrl = (user: string, password: string) => {
    const url = new URL(local.dbUrl);
    url.username = user;
    url.password = password;
    return url.toString();
  };
  const apiSql = createDatabase(
    runtimeUrl("studafy_api_runtime", apiPassword),
    { max: 3 },
  );
  const workerSql = createDatabase(
    runtimeUrl("studafy_worker_runtime", workerPassword),
    { max: 2 },
  );

  const contexts = new AuthContextRepository(apiSql);
  const signingKey = crypto.randomUUID() + crypto.randomUUID();
  const app = new Hono<AuthorizationEnv>();
  app.use("*", requestContext() as never);
  app.use("*", secureResponseHeaders("development") as never);
  app.use("*", async (c, next) => {
    const subject = c.req.header("x-verify-user");
    if (!subject) return c.json({ code: "UNAUTHENTICATED" }, 401);
    const context = await contexts.load(subject);
    if (!context) return c.json({ code: "UNAUTHENTICATED" }, 401);
    const actor: Actor = {
      token: {
        subject,
        sessionId: crypto.randomUUID(),
        issuedAt: Math.floor(Date.now() / 1000),
        expiresAt: Math.floor(Date.now() / 1000) + 600,
        assuranceLevel: "aal1",
        authMethods: [],
        claims: {},
      },
      context,
      aal2: false,
      mfaRequiredByPolicy: false,
    };
    c.set("actor", actor);
    await next();
  });
  app.route(
    "/",
    createFileRoutes(
      {
        repository: new PostgresFileRepository(apiSql),
        storage,
        newIntentsEnabled: true,
        publishEnabled: true,
        delivery: {
          signingKey,
          publicBaseUrl: "http://127.0.0.1:8080",
        },
      },
      createAuthorizationDependencies(
        logger,
        new PostgresAuthorizationRepository(apiSql),
      ),
      { logger, repository: new PostgresIdempotencyRepository(apiSql) },
    ),
  );

  const scan = createFileScanProcessor(
    postgresScanQueue(workerSql),
    storage,
    new FileSecurityScanner(),
    createJsonLogger("worker", "file051-verify", "warn"),
  );
  const cleanupWorker = startFileCleanup(
    workerSql,
    storage,
    createJsonLogger("worker", "file051-verify", "warn"),
    3_600_000,
  );

  const request = (
    user: string,
    method: string,
    path: string,
    body?: unknown,
  ) =>
    app.request(path, {
      method,
      headers: {
        "x-verify-user": user,
        ...(body === undefined ? {} : {
          "content-type": "application/json",
          "idempotency-key": `file051-verify-${crypto.randomUUID()}`,
        }),
      },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }),
    });

  /** Full client flow: intent, direct PUT to the signed URL, completion. */
  const upload = async (
    user: string,
    bytes: Uint8Array,
    mediaType: string,
    displayName: string,
    schoolId: string = IDS.school,
    classroomId: string = IDS.classroom,
  ): Promise<{ fileId: string; objectKey: string }> => {
    const digest = new Uint8Array(
      await crypto.subtle.digest("SHA-256", bytes),
    );
    const sha256 = [...digest].map((b) => b.toString(16).padStart(2, "0"))
      .join("");
    const intent = await request(user, "POST", "/v1/uploads", {
      schoolId,
      purpose: "lesson_resource",
      classroomId,
      displayName,
      expectedSizeBytes: bytes.byteLength,
      declaredMediaType: mediaType,
      sha256,
    });
    if (intent.status !== 201) {
      throw new Error(`intent failed: ${intent.status} ${await intent.text()}`);
    }
    const issued = await intent.json() as {
      session: { id: string };
      uploadUrl: string;
      requiredHeaders: Record<string, string>;
    };
    const put = await fetch(issued.uploadUrl, {
      method: "PUT",
      headers: issued.requiredHeaders,
      body: bytes,
    });
    if (!put.ok) throw new Error(`storage upload failed: ${put.status}`);
    const completed = await request(
      user,
      "POST",
      `/v1/uploads/${issued.session.id}/complete`,
      {},
    );
    if (completed.status !== 200) {
      throw new Error(
        `completion failed: ${completed.status} ${await completed.text()}`,
      );
    }
    const done = await completed.json() as { file: { id: string } };
    const rows = await admin<{ object_key: string }[]>`
      select object_key from public.file_objects where id = ${done.file.id}
    `;
    return { fileId: done.file.id, objectKey: rows[0]!.object_key };
  };

  return {
    admin,
    storage,
    results,
    record,
    request,
    upload,
    scanOnce: () => scan.runOnce(),
    cleanupOnce: () => cleanupWorker.runOnce(),
    async close() {
      await cleanupWorker.close();
      await apiSql.end({ timeout: 5 });
      await workerSql.end({ timeout: 5 });
      await admin.unsafe(`alter role studafy_api_runtime password null`);
      await admin.unsafe(
        `alter role studafy_worker_runtime nologin password null`,
      );
      await cleanup(admin, storage);
      await admin.end({ timeout: 5 });
      const failed = results.filter((result) => !result.pass);
      console.log(
        `\n${results.length - failed.length}/${results.length} checks passed`,
      );
      return failed.length === 0;
    },
  };
}

async function seed(admin: Sql): Promise<void> {
  for (const [id, label] of USERS) {
    await admin`
      insert into auth.users (
        id, email, encrypted_password, aud, role, email_confirmed_at,
        created_at, updated_at, instance_id, confirmation_token, recovery_token,
        email_change, email_change_token_new, email_change_token_current,
        phone_change_token, raw_app_meta_data, raw_user_meta_data
      ) values (
        ${id}::uuid, ${`file051.${label}@synthetic.studafy.test`},
        'synthetic-not-a-secret', 'authenticated', 'authenticated', now(),
        now(), now(), '00000000-0000-0000-0000-000000000000', '', '', '', '',
        '', '', '{}'::jsonb, ${admin.json({ full_name: `FILE-051 ${label}` })}
      )
    `;
  }
  await admin`
    insert into public.schools (id, name, timezone, status) values
      (${IDS.school}::uuid, 'FILE-051 Verify School', 'Asia/Riyadh', 'active'),
      (${IDS.otherSchool}::uuid, 'FILE-051 Other School', 'Asia/Riyadh', 'active')
  `;
  await admin`
    insert into public.memberships (school_id, user_id, role, active, status) values
      (${IDS.school}::uuid, ${IDS.teacher}::uuid, 'teacher', true, 'active'),
      (${IDS.school}::uuid, ${IDS.student}::uuid, 'student', true, 'active'),
      (${IDS.school}::uuid, ${IDS.unenrolled}::uuid, 'student', true, 'active'),
      (${IDS.school}::uuid, ${IDS.operator}::uuid, 'school_admin', true, 'active'),
      (${IDS.otherSchool}::uuid, ${IDS.otherTeacher}::uuid, 'teacher', true, 'active')
  `;
  await admin`
    insert into public.terms (id, school_id, name, starts_on, ends_on, active)
    values (${IDS.term}::uuid, ${IDS.school}::uuid, 'FILE-051 Term',
      current_date - 30, current_date + 90, true)
  `;
  await admin`
    insert into public.classrooms (id, school_id, term_id, name, grade, section, teacher_id)
    values (${IDS.classroom}::uuid, ${IDS.school}::uuid, ${IDS.term}::uuid,
      'FILE-051 Classroom', 'G8', 'V', ${IDS.teacher}::uuid)
  `;
  await admin`
    insert into public.classroom_staff (school_id, classroom_id, membership_id, user_id, role)
    select ${IDS.school}::uuid, ${IDS.classroom}::uuid, m.id, ${IDS.teacher}::uuid, 'lead_teacher'
    from public.memberships m
    where m.school_id = ${IDS.school}::uuid and m.user_id = ${IDS.teacher}::uuid
  `;
  await admin`
    insert into public.students (id, school_id, user_id, studafy_id, display_name, provisional, created_by)
    values
      (${IDS.studentRecord}::uuid, ${IDS.school}::uuid, ${IDS.student}::uuid,
        'STU-F051-E2E-1', 'FILE-051 Student', false, ${IDS.teacher}::uuid),
      (${IDS.unenrolledRecord}::uuid, ${IDS.school}::uuid, ${IDS.unenrolled}::uuid,
        'STU-F051-E2E-2', 'FILE-051 Unenrolled', false, ${IDS.teacher}::uuid)
  `;
  await admin`
    insert into public.enrollments (classroom_id, student_id, active)
    values (${IDS.classroom}::uuid, ${IDS.studentRecord}::uuid, true)
  `;
}

async function cleanup(
  admin: Sql,
  storage: SupabasePrivateFileStorage,
): Promise<void> {
  const schools = [IDS.school, IDS.otherSchool];
  const keys = await admin<{ bucket: string; object_key: string }[]>`
    select bucket, object_key from public.upload_sessions
    where school_id in ${admin(schools)}
  `;
  for (const key of keys) {
    await storage.delete(key.bucket, key.object_key).catch(() => undefined);
  }
  await admin.begin(async (tx) => {
    await tx`alter table public.audit_events disable trigger db020_reject_mutation`;
    await tx`alter table public.resource_versions disable trigger db020_reject_mutation`;
    await tx`delete from public.file_delivery_grants where school_id in ${
      tx(schools)
    }`;
    await tx`delete from public.resource_publications where school_id in ${
      tx(schools)
    }`;
    await tx`delete from public.file_bindings where school_id in ${
      tx(schools)
    }`;
    await tx`delete from public.resource_versions where school_id in ${
      tx(schools)
    }`;
    await tx`delete from public.resources where school_id in ${tx(schools)}`;
    await tx`delete from public.file_job_outbox where school_id in ${
      tx(schools)
    }`;
    await tx`delete from public.upload_sessions where school_id in ${
      tx(schools)
    }`;
    await tx`update public.file_objects set dedup_source_file_id = null where school_id in ${
      tx(schools)
    }`;
    await tx`delete from public.file_objects where school_id in ${tx(schools)}`;
    await tx`delete from public.idempotency_records where school_id in ${
      tx(schools)
    }`;
    await tx`delete from public.audit_events where school_id in ${tx(schools)}`;
    await tx`delete from public.enrollments where school_id in ${tx(schools)}`;
    await tx`delete from public.students where school_id in ${tx(schools)}`;
    await tx`delete from public.classroom_staff where school_id in ${
      tx(schools)
    }`;
    await tx`delete from public.classrooms where school_id in ${tx(schools)}`;
    await tx`delete from public.terms where school_id in ${tx(schools)}`;
    await tx`delete from public.file_quota_policies where school_id in ${
      tx(schools)
    }`;
    await tx`delete from public.memberships where school_id in ${tx(schools)}`;
    await tx`delete from public.schools where id in ${tx(schools)}`;
    await tx`delete from auth.users where id in ${tx(USERS.map(([id]) => id))}`;
    await tx`alter table public.resource_versions enable trigger db020_reject_mutation`;
    await tx`alter table public.audit_events enable trigger db020_reject_mutation`;
  });
}

/** Deterministic JPEG carrying EXIF with a GPS marker, for transform proof. */
export function jpegWithExif(seed: string): Uint8Array {
  const encoder = new TextEncoder();
  const parts: number[] = [0xff, 0xd8];
  const emit = (marker: number, payload: number[]) =>
    parts.push(
      0xff,
      marker,
      (payload.length + 2) >> 8,
      (payload.length + 2) & 0xff,
      ...payload,
    );
  emit(0xe1, [...encoder.encode(`Exif\0\0GPS 51.5N 0.1W ${seed}`)]);
  emit(0xdb, [0x00, 1, 2, 3]);
  emit(0xc0, [8, 1, 1, 1, 1, 1]);
  emit(0xc4, [0x00, 0x01]);
  parts.push(0xff, 0xda, 0x00, 0x04, 0x01, 0x00, 0x12, 0x34, 0x56, 0x78);
  parts.push(0xff, 0xd9);
  return Uint8Array.from(parts);
}

/** A PDF-signature file carrying the EICAR test string (not malware). */
export function eicarPdf(): Uint8Array {
  return new TextEncoder().encode(
    "%PDF-1.7\n" +
      "X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*" +
      "\n%%EOF\n",
  );
}

export function hasBytes(haystack: Uint8Array, text: string): boolean {
  return new TextDecoder("latin1").decode(haystack).includes(text);
}

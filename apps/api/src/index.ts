import { Hono } from "hono";
import { describeApiEnv, loadApiEnv } from "./bootstrap/config";
import { createApp, type DependentCheck } from "./bootstrap/app";
import { authIssuer, authJwksUrl } from "@studafy/config";
import { AuthContextRepository } from "./auth/context";
import { JwksKeySource } from "./auth/jwks";
import { createAuthRoutes } from "./auth/routes";
import { PostgresAuthorizationRepository } from "./authorization/repository";
import {
  type AuthorizationEnv,
  createAuthorizationDependencies,
} from "./authorization/middleware";
import { PostgresIdempotencyRepository } from "./platform/idempotency";
import { createRedactingLogger } from "./platform/logging";
import { createAcademicRoutes } from "./academic/routes";
import { PostgresAcademicRepository } from "./academic/repository";
import {
  createSchoolAdminRoutes,
  createSchoolRosterRoutes,
} from "./school-admin/routes";
import { PostgresSchoolAdminRepository } from "./school-admin/repository";
import { createInvitationsRoutes } from "./invitations/routes";
import { PostgresInvitationsRepository } from "./invitations/repository";
import { createFamilyRoutes } from "./family/routes";
import { PostgresFamilyRepository } from "./family/repository";
import { createCommunicationsRoutes } from "./communications/routes";
import { PostgresCommunicationsRepository } from "./communications/repository";
import { createMeetingsRoutes } from "./meetings/routes";
import { PostgresMeetingsRepository } from "./meetings/repository";
import { createNotificationsRoutes } from "./notifications/routes";
import { PostgresNotificationsRepository } from "./notifications/repository";
import { createAccountRoutes } from "./account/routes";
import { PostgresAccountRepository } from "./account/repository";
import { createSupportAccessRoutes } from "./support-access/routes";
import { PostgresSupportAccessRepository } from "./support-access/repository";
import { createSafetyRoutes } from "./safety/routes";
import { PostgresSafetyRepository } from "./safety/repository";
import {
  checkDatabase,
  closeDatabase,
  createDatabase,
} from "@studafy/database";
import { checkRedis, closeRedis, createRedis } from "@studafy/infrastructure";
import {
  createJsonLogger,
  installGracefulShutdown,
  logListening,
  logStartup,
} from "@studafy/observability";
import { version as apiVersion } from "../package.json";

const env = loadApiEnv();
const logger = createRedactingLogger(
  createJsonLogger("api", apiVersion, env.LOG_LEVEL),
);

logStartup(logger, {
  environment: env.ENVIRONMENT,
  runtime: `bun ${Bun.version}`,
  configuration: describeApiEnv(env),
});

const sql = env.DATABASE_URL ? createDatabase(env.DATABASE_URL) : undefined;
const redis = env.REDIS_URL ? createRedis(env.REDIS_URL) : undefined;

const databaseCheck: DependentCheck | undefined = sql
  ? () => checkDatabase(sql)
  : undefined;
const redisCheck: DependentCheck | undefined = redis
  ? () => checkRedis(redis)
  : undefined;

// AUTH-030 needs both a verified token source and a database. Without either
// the auth routes are not mounted at all, so /v1 keeps answering
// NOT_IMPLEMENTED instead of exposing handlers that cannot authenticate.
const authorization = createAuthorizationDependencies(
  logger,
  sql ? new PostgresAuthorizationRepository(sql) : undefined,
);
const idempotencyDependencies = {
  logger,
  ...(sql ? { repository: new PostgresIdempotencyRepository(sql) } : {}),
};

// Built ahead of the route modules below so school-admin (closeSchool,
// suspendSchool) and account (requestDataExport) can require the same
// recent-auth/AAL2 grants AUTH-030's own routes require, instead of each
// carrying a separate, easy-to-diverge copy of these settings.
const authDependencies = sql && env.SUPABASE_URL
  ? {
    keys: new JwksKeySource(authJwksUrl(env.SUPABASE_URL)),
    repository: new AuthContextRepository(sql),
    logger,
    issuer: authIssuer(env.SUPABASE_URL),
    audience: env.AUTH_JWT_AUDIENCE,
    clockSkewSeconds: env.AUTH_CLOCK_SKEW_SECONDS,
    revocationBudgetSeconds: env.AUTH_REVOCATION_BUDGET_SECONDS,
    reauthTtlSeconds: env.AUTH_REAUTH_TTL_SECONDS,
    deletionGraceDays: env.AUTH_DELETION_GRACE_DAYS,
  }
  : undefined;
const academic = sql && env.API_CURSOR_SIGNING_KEY
  ? createAcademicRoutes(
    {
      repository: new PostgresAcademicRepository(sql),
      cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
      enabledSlices: {
        classes: env.API041_CLASSES_ENABLED,
        content: env.API041_CONTENT_ENABLED,
        assignments: env.API041_ASSIGNMENTS_ENABLED,
        assessments: env.API041_ASSESSMENTS_ENABLED,
        grades: env.API041_GRADES_ENABLED,
        attendance: env.API041_ATTENDANCE_ENABLED,
        wellbeing: env.API041_WELLBEING_ENABLED,
      },
    },
    authorization,
    idempotencyDependencies,
  )
  : undefined;

const schoolAdmin = sql && env.API_CURSOR_SIGNING_KEY && authDependencies
  ? createSchoolAdminRoutes(
    {
      repository: new PostgresSchoolAdminRepository(sql),
      cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
      enabledSlices: {
        schools: env.API042_SCHOOLS_ENABLED,
        memberships: env.API042_MEMBERSHIPS_ENABLED,
        staffing: env.API042_STAFFING_ENABLED,
        enrollment: env.API042_ENROLLMENT_ENABLED,
      },
    },
    authorization,
    idempotencyDependencies,
    authDependencies,
  )
  : undefined;

const invitations = sql && env.API_CURSOR_SIGNING_KEY
  ? createInvitationsRoutes(
    {
      repository: new PostgresInvitationsRepository(sql),
      cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
      enabledSlices: { invitations: env.API042_INVITATIONS_ENABLED },
    },
    authorization,
    idempotencyDependencies,
  )
  : undefined;

const family = sql && env.API_CURSOR_SIGNING_KEY
  ? createFamilyRoutes(
    {
      repository: new PostgresFamilyRepository(sql),
      cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
      enabledSlices: { family: env.API042_FAMILY_ENABLED },
    },
    authorization,
    idempotencyDependencies,
  )
  : undefined;

const communications = sql && env.API_CURSOR_SIGNING_KEY
  ? createCommunicationsRoutes(
    {
      repository: new PostgresCommunicationsRepository(sql),
      cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
      enabledSlices: {
        conversations: env.API042_CONVERSATIONS_ENABLED,
        announcements: env.API042_ANNOUNCEMENTS_ENABLED,
      },
    },
    authorization,
    idempotencyDependencies,
  )
  : undefined;

const meetings = sql && env.API_CURSOR_SIGNING_KEY
  ? createMeetingsRoutes(
    {
      repository: new PostgresMeetingsRepository(sql),
      cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
      enabledSlices: { meetings: env.API042_MEETINGS_ENABLED },
    },
    authorization,
    idempotencyDependencies,
  )
  : undefined;

const notifications = sql && env.API_CURSOR_SIGNING_KEY
  ? createNotificationsRoutes(
    {
      repository: new PostgresNotificationsRepository(sql),
      cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
      enabledSlices: { notifications: env.API042_NOTIFICATIONS_ENABLED },
    },
    authorization,
    idempotencyDependencies,
  )
  : undefined;

const account = sql && env.API_CURSOR_SIGNING_KEY && authDependencies
  ? createAccountRoutes(
    {
      repository: new PostgresAccountRepository(sql),
      cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
      enabledSlices: { account: env.API042_ACCOUNT_RIGHTS_ENABLED },
    },
    authorization,
    idempotencyDependencies,
    authDependencies,
  )
  : undefined;

const supportAccess = sql && env.API_CURSOR_SIGNING_KEY
  ? createSupportAccessRoutes(
    {
      repository: new PostgresSupportAccessRepository(sql),
      cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
      enabledSlices: { supportAccess: env.API042_SUPPORT_ACCESS_ENABLED },
    },
    authorization,
    idempotencyDependencies,
  )
  : undefined;

// SAFE-043 safety & safeguarding. The symmetric block gate over API-042
// conversations lives in the database dispatcher and is unconditional once
// these migrations are applied; the API surface is gated per slice here.
const safety = sql && env.API_CURSOR_SIGNING_KEY
  ? createSafetyRoutes(
    {
      repository: new PostgresSafetyRepository(sql),
      cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
      enabledSlices: {
        reporting: env.SAFE043_REPORTING_ENABLED,
        blocks: env.SAFE043_BLOCKS_ENABLED,
        moderation: env.SAFE043_MODERATION_ENABLED,
        contentControls: env.SAFE043_CONTENT_CONTROLS_ENABLED,
      },
    },
    authorization,
    idempotencyDependencies,
  )
  : undefined;

// createTerm/createStudent are the last two entries in V1_ROUTE_CATALOGUE
// before the SAFE-043 block (see school-admin/routes.ts's
// SCHOOL_ROSTER_ROUTES comment) and must be mounted in catalogue order so
// the AUTH-031 parity test's mounted-route order matches the catalogue.
const schoolRoster = sql && env.API_CURSOR_SIGNING_KEY
  ? createSchoolRosterRoutes(
    {
      repository: new PostgresSchoolAdminRepository(sql),
      cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
      enabledSlices: { schools: env.API042_SCHOOLS_ENABLED },
    },
    authorization,
    idempotencyDependencies,
  )
  : undefined;

// createAuthRoutes mounts one companion router at "/"; every API-042 module
// is combined here first so each rides along on the same slot instead of
// widening that function's signature every time a new module lands.
const combinedRoutes =
  academic || schoolAdmin || invitations || family || communications ||
    meetings || notifications || account || supportAccess || schoolRoster ||
    safety
    ? (() => {
      const combined = new Hono<AuthorizationEnv>();
      if (academic) combined.route("/", academic);
      if (schoolAdmin) combined.route("/", schoolAdmin);
      if (invitations) combined.route("/", invitations);
      if (family) combined.route("/", family);
      if (communications) combined.route("/", communications);
      if (meetings) combined.route("/", meetings);
      if (notifications) combined.route("/", notifications);
      if (account) combined.route("/", account);
      if (supportAccess) combined.route("/", supportAccess);
      if (schoolRoster) combined.route("/", schoolRoster);
      if (safety) combined.route("/", safety);
      return combined;
    })()
    : undefined;

const auth = authDependencies
  ? createAuthRoutes(
    authDependencies,
    authorization,
    idempotencyDependencies,
    combinedRoutes,
  )
  : undefined;

if (!auth) {
  logger.warn("auth_routes_disabled", {
    reason: !env.SUPABASE_URL ? "supabase_url_missing" : "database_missing",
  });
}

const app = createApp({
  info: {
    service: "api",
    version: apiVersion,
    environment: env.ENVIRONMENT,
  },
  logger,
  checks: { database: databaseCheck, redis: redisCheck },
  platform: {
    allowedOrigins: env.API_ALLOWED_ORIGINS,
    limits: {
      maxBodyBytes: env.API_MAX_BODY_BYTES,
      requestTimeoutMs: env.API_REQUEST_TIMEOUT_MS,
    },
  },
  ...(auth ? { auth } : {}),
});

const server = Bun.serve({
  port: env.API_PORT,
  maxRequestBodySize: env.API_MAX_BODY_BYTES,
  fetch: app.fetch,
});

logListening(logger, { port: server.port ?? env.API_PORT });

installGracefulShutdown({
  logger,
  onClose: async () => {
    server.stop(false);
    if (sql) await closeDatabase(sql);
    if (redis) await closeRedis(redis);
  },
});

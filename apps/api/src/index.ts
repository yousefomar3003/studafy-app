import { createTurnstilePage } from "./turnstile/page";
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
import { RedisAuthContextCache } from "./platform/cache/authContextCache";
import {
  createRateLimitDependencies,
  rateLimitAuto,
  rateLimitEdge,
} from "./platform/rate-limit/middleware";
import {
  createAcademicAppendedRoutes,
  createAcademicRoutes,
} from "./academic/routes";
import { PostgresAcademicRepository } from "./academic/repository";
import {
  createSchoolAdminRoutes,
  createSchoolRosterRoutes,
} from "./school-admin/routes";
import { PostgresSchoolAdminRepository } from "./school-admin/repository";
import { createInvitationsRoutes } from "./invitations/routes";
import { PostgresInvitationsRepository } from "./invitations/repository";
import {
  createFamilyReadRoutes,
  createFamilyRoutes,
  createStudentFamilyRoutes,
} from "./family/routes";
import { PostgresFamilyRepository } from "./family/repository";
import { createClassJoinRoutes } from "./class-join/routes";
import { PostgresClassJoinRepository } from "./class-join/repository";
import {
  createCommunicationsRoutes,
  createContactsRoutes,
} from "./communications/routes";
import { PostgresCommunicationsRepository } from "./communications/repository";
import { createMeetingsRoutes } from "./meetings/routes";
import { PostgresMeetingsRepository } from "./meetings/repository";
import {
  createNotificationsRoutes,
  createPushDeviceRoutes,
} from "./notifications/routes";
import { PostgresNotificationsRepository } from "./notifications/repository";
import { createAccountReadRoutes, createAccountRoutes } from "./account/routes";
import { PostgresAccountRepository } from "./account/repository";
import { createSupportAccessRoutes } from "./support-access/routes";
import { PostgresSupportAccessRepository } from "./support-access/repository";
import { createSafetyRoutes } from "./safety/routes";
import { PostgresSafetyRepository } from "./safety/repository";
import { createFileRoutes } from "./files/routes";
import { PostgresFileRepository } from "./files/repository";
import { SupabasePrivateFileStorage } from "./files/storage";
import { createBillingRoutes } from "./billing/routes";
import { createBillingWebhookRoutes } from "./billing/webhookRoutes";
import { PostgresBillingRepository } from "./billing/repository";
import { RealAppleTransactionVerifier } from "./billing/appleVerifier";
import { RealGooglePurchaseVerifier } from "./billing/googleVerifier";
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

// OPS-060. Rate limiting and the revocation-safe session-context cache share
// one Redis client; production is required to configure the HMAC secret
// (enforceApiFailClosed), development mints an ephemeral one for the boot so
// no identifier is ever stored raw in a Redis key either way.
const ephemeralSecret = env.RATE_LIMIT_HMAC_SIGNING_KEY == null &&
  env.RATE_LIMIT_ENABLED;
if (ephemeralSecret) {
  logger.warn("rate_limit_hmac_ephemeral", {
    environment: env.ENVIRONMENT,
  });
}
const rateLimitSecret = env.RATE_LIMIT_HMAC_SIGNING_KEY ??
  `${crypto.randomUUID()}${crypto.randomUUID()}`;
const rateLimitDependencies = createRateLimitDependencies({
  enabled: env.RATE_LIMIT_ENABLED,
  secret: rateLimitSecret,
  redis: redis ?? null,
  logger,
  trustCloudflare: env.ENVIRONMENT === "production",
});

// The session-context cache: version-keyed (membershipVersion, revocation
// watermark, profile state ride along in the generation), TTL clamped to
// min(30s, AUTH_REVOCATION_BUDGET_SECONDS), failing back to the DB loader
// whenever Redis cannot serve.
const authContextCache = env.RATE_LIMIT_ENABLED && redis
  ? new RedisAuthContextCache(redis, rateLimitSecret, {
    environment: env.ENVIRONMENT,
    budgetSeconds: env.AUTH_REVOCATION_BUDGET_SECONDS,
  })
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
    repository: new AuthContextRepository(sql, authContextCache),
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

const academicAppended = sql && env.API_CURSOR_SIGNING_KEY
  ? createAcademicAppendedRoutes(
    {
      repository: new PostgresAcademicRepository(sql),
      cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
      enabledSlices: { classes: env.API041_CLASSES_ENABLED },
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

const turnstile = env.TURNSTILE_ENABLED
  ? {
    secret: env.TURNSTILE_SECRET!,
    siteKey: env.TURNSTILE_SITE_KEY!,
    hostnames: env.TURNSTILE_HOSTNAMES,
  }
  : undefined;

const familyDependencies = sql && env.API_CURSOR_SIGNING_KEY
  ? {
    repository: new PostgresFamilyRepository(sql),
    turnstile,
    cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
    enabledSlices: { family: env.API042_FAMILY_ENABLED },
  }
  : undefined;
const family = familyDependencies
  ? createFamilyRoutes(
    familyDependencies,
    authorization,
    idempotencyDependencies,
  )
  : undefined;
const familyReads = familyDependencies
  ? createFamilyReadRoutes(
    familyDependencies,
    authorization,
    idempotencyDependencies,
  )
  : undefined;

const classJoin = sql && env.API_CURSOR_SIGNING_KEY
  ? createClassJoinRoutes(
    {
      repository: new PostgresClassJoinRepository(sql),
      cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
      enabledSlices: { classJoin: true },
    },
    authorization,
    idempotencyDependencies,
  )
  : undefined;

const communicationsDependencies = sql && env.API_CURSOR_SIGNING_KEY
  ? {
    repository: new PostgresCommunicationsRepository(sql),
    cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
    enabledSlices: {
      conversations: env.API042_CONVERSATIONS_ENABLED,
      announcements: env.API042_ANNOUNCEMENTS_ENABLED,
    },
  }
  : undefined;
const communications = communicationsDependencies
  ? createCommunicationsRoutes(
    communicationsDependencies,
    authorization,
    idempotencyDependencies,
  )
  : undefined;
const contacts = communicationsDependencies
  ? createContactsRoutes(
    communicationsDependencies,
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

const notificationsDependencies = sql && env.API_CURSOR_SIGNING_KEY
  ? {
    repository: new PostgresNotificationsRepository(sql),
    cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
    enabledSlices: { notifications: env.API042_NOTIFICATIONS_ENABLED },
  }
  : undefined;
const notifications = notificationsDependencies
  ? createNotificationsRoutes(
    notificationsDependencies,
    authorization,
    idempotencyDependencies,
  )
  : undefined;
const pushDevices = notificationsDependencies
  ? createPushDeviceRoutes(
    notificationsDependencies,
    authorization,
    idempotencyDependencies,
  )
  : undefined;

const accountDependencies = sql && env.API_CURSOR_SIGNING_KEY
  ? {
    repository: new PostgresAccountRepository(sql),
    cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
    enabledSlices: { account: env.API042_ACCOUNT_RIGHTS_ENABLED },
  }
  : undefined;
const account = accountDependencies && authDependencies
  ? createAccountRoutes(
    accountDependencies,
    authorization,
    idempotencyDependencies,
    authDependencies,
  )
  : undefined;
const accountReads = accountDependencies
  ? createAccountReadRoutes(
    accountDependencies,
    authorization,
    idempotencyDependencies,
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

// FILE-050 uses the service role only inside the isolated storage adapter.
// Database authorization and mutation still run as studafy_api_runtime via
// the narrow private.api050_* surface. With no key the routes do not mount.
const files = sql && env.SUPABASE_URL && env.SUPABASE_SERVICE_ROLE_KEY
  ? createFileRoutes(
    {
      repository: new PostgresFileRepository(sql),
      storage: new SupabasePrivateFileStorage(
        env.SUPABASE_URL,
        env.SUPABASE_SERVICE_ROLE_KEY,
      ),
      newIntentsEnabled: env.FILE050_NEW_INTENTS_ENABLED,
      // FILE-051 switches default off; delivery also needs its own signing
      // key and public origin (production refuses to start without them).
      publishEnabled: env.FILE051_PUBLISH_ENABLED,
      delivery: env.FILE051_DELIVERY_ENABLED &&
          env.FILE051_DELIVERY_SIGNING_KEY &&
          env.FILE051_DELIVERY_PUBLIC_BASE_URL
        ? {
          signingKey: env.FILE051_DELIVERY_SIGNING_KEY,
          publicBaseUrl: env.FILE051_DELIVERY_PUBLIC_BASE_URL,
        }
        : null,
    },
    authorization,
    idempotencyDependencies,
  )
  : undefined;

// PAY-071. Apple/Google are wired independently: a store not yet configured
// with credentials simply answers SERVICE_UNAVAILABLE for that platform's
// submit/restore/webhook path, rather than the whole module refusing to
// mount. Root certificates are never embedded in this codebase - only
// decoded from the operator-supplied base64 env value.
const appleConfig = env.APPLE_BUNDLE_ID && env.APPLE_ENVIRONMENT &&
    env.APPLE_ISSUER_ID && env.APPLE_KEY_ID && env.APPLE_PRIVATE_KEY &&
    env.APPLE_ROOT_CERTIFICATES_BASE64
  ? {
    verifier: new RealAppleTransactionVerifier({
      rootCertificates: env.APPLE_ROOT_CERTIFICATES_BASE64.split(",")
        .map((value) => Buffer.from(value.trim(), "base64")),
      bundleId: env.APPLE_BUNDLE_ID,
      environment: env.APPLE_ENVIRONMENT,
      appAppleId: env.APPLE_APP_APPLE_ID,
      api: {
        signingKey: env.APPLE_PRIVATE_KEY,
        keyId: env.APPLE_KEY_ID,
        issuerId: env.APPLE_ISSUER_ID,
      },
    }),
    bundleId: env.APPLE_BUNDLE_ID,
    platformEnvironment: env.APPLE_ENVIRONMENT,
  }
  : null;

const googleConfig =
  env.GOOGLE_PACKAGE_NAME && env.GOOGLE_SERVICE_ACCOUNT_JSON &&
    env.GOOGLE_PUBSUB_AUDIENCE && env.GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL
    ? {
      verifier: new RealGooglePurchaseVerifier({
        serviceAccountJson: env.GOOGLE_SERVICE_ACCOUNT_JSON,
        pubsubAudience: env.GOOGLE_PUBSUB_AUDIENCE,
        pubsubServiceAccountEmail: env.GOOGLE_PUBSUB_SERVICE_ACCOUNT_EMAIL,
      }),
      packageName: env.GOOGLE_PACKAGE_NAME,
    }
    : null;

const billingRepository = sql ? new PostgresBillingRepository(sql) : undefined;
const billing = sql && env.PAY071_BILLING_ENABLED && env.PAY071_ENVIRONMENT &&
    authDependencies && billingRepository
  ? createBillingRoutes(
    {
      repository: billingRepository,
      environment: env.PAY071_ENVIRONMENT,
      apple: appleConfig,
      google: googleConfig,
    },
    authorization,
    idempotencyDependencies,
    authDependencies,
  )
  : undefined;

const billingWebhooks = sql && env.PAY071_BILLING_ENABLED &&
    env.PAY071_ENVIRONMENT && billingRepository
  ? createBillingWebhookRoutes({
    repository: billingRepository,
    environment: env.PAY071_ENVIRONMENT,
    apple: appleConfig ? { verifier: appleConfig.verifier } : null,
    google: googleConfig ? { verifier: googleConfig.verifier } : null,
    logger,
  })
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
    safety || files || billing || contacts || familyReads || accountReads ||
    pushDevices
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
      if (files) combined.route("/", files);
      if (billing) combined.route("/", billing);
      if (contacts) combined.route("/", contacts);
      if (familyReads) combined.route("/", familyReads);
      if (accountReads) combined.route("/", accountReads);
      if (pushDevices) combined.route("/", pushDevices);
      // Appended last: these routes sit at the end of the contract
      // catalogue, and mount order is asserted to equal catalogue order.
      if (classJoin) combined.route("/", classJoin);
      if (academicAppended) combined.route("/", academicAppended);
      if (familyDependencies) {
        combined.route(
          "/",
          createStudentFamilyRoutes(
            familyDependencies,
            authorization,
            idempotencyDependencies,
          ),
        );
      }
      return combined;
    })()
    : undefined;

const auth = authDependencies
  ? createAuthRoutes(
    authDependencies,
    authorization,
    idempotencyDependencies,
    combinedRoutes,
    env.RATE_LIMIT_ENABLED ? rateLimitAuto(rateLimitDependencies) : undefined,
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
  ...(env.RATE_LIMIT_ENABLED
    ? { rateLimit: { edge: rateLimitEdge(rateLimitDependencies) } }
    : {}),
  ...(auth ? { auth } : {}),
  ...(turnstile ? { challengePage: createTurnstilePage(turnstile) } : {}),
  ...(billingWebhooks ? { webhooks: billingWebhooks } : {}),
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

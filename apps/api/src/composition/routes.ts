import { Hono } from "hono";
import { type AuthorizationEnv } from "../authorization/middleware";
import {
  createAcademicAppendedRoutes,
  createAcademicRoutes,
  createSubmissionHistoryRoutes,
} from "../academic/routes";
import { PostgresAcademicRepository } from "../academic/repository";
import {
  createSchoolAdminRoutes,
  createSchoolRosterRoutes,
} from "../school-admin/routes";
import { PostgresSchoolAdminRepository } from "../school-admin/repository";
import { createInvitationsRoutes } from "../invitations/routes";
import { PostgresInvitationsRepository } from "../invitations/repository";
import {
  createFamilyReadRoutes,
  createFamilyRoutes,
  createStudentFamilyRoutes,
} from "../family/routes";
import { PostgresFamilyRepository } from "../family/repository";
import { createClassJoinRoutes } from "../class-join/routes";
import { createOnboardingRoutes } from "../onboarding/routes";
import { createStudyAssistantRoutes } from "../study-assistant/routes";
import { PostgresStudyRepository } from "../study/repository";
import { createStudyRoutes } from "../study/routes";
import { createFamilyInsightsRoutes } from "../family-insights/routes";
import { PostgresFamilyInsightsRepository } from "../family-insights/repository";
import { PostgresOnboardingRepository } from "../onboarding/repository";
import { PostgresClassJoinRepository } from "../class-join/repository";
import {
  createCommunicationsRoutes,
  createContactsRoutes,
  createMessageReceiptRoutes,
} from "../communications/routes";
import { PostgresCommunicationsRepository } from "../communications/repository";
import {
  createMeetingListRoutes,
  createMeetingsRoutes,
} from "../meetings/routes";
import { PostgresMeetingsRepository } from "../meetings/repository";
import {
  createNotificationsRoutes,
  createPushDeviceRoutes,
} from "../notifications/routes";
import { PostgresNotificationsRepository } from "../notifications/repository";
import {
  createAccountReadRoutes,
  createAccountRoutes,
} from "../account/routes";
import { PostgresAccountRepository } from "../account/repository";
import { createSupportAccessRoutes } from "../support-access/routes";
import { PostgresSupportAccessRepository } from "../support-access/repository";
import { createSafetyRoutes } from "../safety/routes";
import { PostgresSafetyRepository } from "../safety/repository";
import { createFileRoutes } from "../files/routes";
import { PostgresFileRepository } from "../files/repository";
import {
  createStudyAssistant,
  RealAppleTransactionVerifier,
  RealGooglePurchaseVerifier,
  SupabasePrivateFileStorage,
} from "@studafy/infrastructure";
import { createBillingRoutes } from "../billing/routes";
import { createBillingWebhookRoutes } from "../billing/webhookRoutes";
import { PostgresBillingRepository } from "../billing/repository";
import type { Platform } from "./platform";

/**
 * Builds every /v1 module the configuration enables, and combines them into
 * the one router the auth module mounts. A module whose settings are missing
 * is simply absent, so /v1 answers NOT_IMPLEMENTED for it rather than
 * exposing handlers that cannot work.
 */
export function buildRoutes(platform: Platform) {
  const {
    env,
    sql,
    logger,
    authorization,
    idempotencyDependencies,
    authDependencies,
    invalidateActorContext,
  } = platform;

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

  const submissionHistory = sql && env.API_CURSOR_SIGNING_KEY
    ? createSubmissionHistoryRoutes(
      {
        repository: new PostgresAcademicRepository(sql),
        cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
        enabledSlices: { assignments: env.API041_ASSIGNMENTS_ENABLED },
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
        repository: new PostgresClassJoinRepository(
          sql,
          env.CLASS_JOIN_CODE_KEY,
        ),
        cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
        enabledSlices: { classJoin: true },
        invalidateActorContext: invalidateActorContext,
      },
      authorization,
      idempotencyDependencies,
    )
    : undefined;

  const onboarding = sql && env.API_CURSOR_SIGNING_KEY
    ? createOnboardingRoutes(
      {
        repository: new PostgresOnboardingRepository(sql),
        cursorSigningKey: env.API_CURSOR_SIGNING_KEY,
        enabledSlices: { onboarding: true },
        invalidateActorContext: invalidateActorContext,
      },
      authorization,
      idempotencyDependencies,
    )
    : undefined;

  // The study assistant needs three things at once: a provider key, the single
  // origin it is allowed to reach, and Redis for the daily spend ceiling. Any
  // missing and the route is simply absent - the app then shows no AI tab,
  // which is the honest state rather than a tab that always errors.
  const aiPrices = {
    inputUsdPerMTok: env.AI_PRICE_INPUT_USD_PER_MTOK,
    outputUsdPerMTok: env.AI_PRICE_OUTPUT_USD_PER_MTOK,
  };
  const aiAssistant = env.AI_API_KEY && env.AI_BASE_URL
    ? createStudyAssistant({
      apiKey: env.AI_API_KEY,
      baseUrl: env.AI_BASE_URL,
      model: env.AI_MODEL,
      // Inside the API's own request limit, so a slow answer fails as
      // "unavailable" rather than as a gateway timeout. 500 tokens is a full
      // explanation for a student and comes back in ~3-4s.
      maxOutputTokens: 500,
      maxLongOutputTokens: 1_100,
      timeoutMs: 8_500,
    })
    : null;
  const studyRepository = sql ? new PostgresStudyRepository(sql) : null;

  // The question box needs the provider and the cost ledger. Without either
  // the route is absent and the app shows no AI tab, which is the honest state
  // rather than a tab that always errors.
  const studyAssistant = aiAssistant && studyRepository
    ? createStudyAssistantRoutes(
      { assistant: aiAssistant, repository: studyRepository, prices: aiPrices },
      authorization,
    )
    : undefined;

  const familyInsights = sql
    ? createFamilyInsightsRoutes(
      { repository: new PostgresFamilyInsightsRepository(sql) },
      authorization,
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

  const messageReceipts = communicationsDependencies
    ? createMessageReceiptRoutes(
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

  const meetingList = sql && env.API_CURSOR_SIGNING_KEY
    ? createMeetingListRoutes(
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
  // STORAGE_URL and its key only in the development split; everywhere else
  // they are unset and the files live in the SUPABASE_URL project.
  const storageUrl = env.STORAGE_URL ?? env.SUPABASE_URL;
  const storageKey = env.STORAGE_SERVICE_ROLE_KEY ??
    env.SUPABASE_SERVICE_ROLE_KEY;
  const files = sql && storageUrl && storageKey
    ? createFileRoutes(
      {
        repository: new PostgresFileRepository(sql),
        storage: new SupabasePrivateFileStorage(storageUrl, storageKey),
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

  // Studafy Plus / Max and the Notebook. Present whenever there is a database:
  // the notebook and the plan summary need no AI; the AI routes answer
  // AI_FEATURE_DISABLED until a provider and the lesson-tools switch are set.
  const study = studyRepository && idempotencyDependencies
    ? createStudyRoutes(
      {
        repository: studyRepository,
        prices: aiPrices,
        assistant: aiAssistant,
        lessonToolsEnabled: env.AI_LESSON_TOOLS_ENABLED,
        storage: storageUrl && storageKey
          ? new SupabasePrivateFileStorage(storageUrl, storageKey)
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

  const billingRepository = sql
    ? new PostgresBillingRepository(sql)
    : undefined;
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

  // Mounted in catalogue order: the authorization parity test asserts that
  // mount order equals the order routes appear in the contract catalogue.
  const studentFamily = familyDependencies
    ? createStudentFamilyRoutes(
      familyDependencies,
      authorization,
      idempotencyDependencies,
    )
    : undefined;
  const modules = [
    academic,
    schoolAdmin,
    invitations,
    family,
    communications,
    meetings,
    notifications,
    account,
    supportAccess,
    schoolRoster,
    safety,
    files,
    billing,
    contacts,
    familyReads,
    accountReads,
    pushDevices,
    classJoin,
    academicAppended,
    studentFamily,
    onboarding,
    studyAssistant,
    familyInsights,
    submissionHistory,
    meetingList,
    messageReceipts,
    study,
  ].filter((module) => module !== undefined && module !== null);
  const combinedRoutes = modules.length > 0
    ? modules.reduce(
      (combined, module) => combined.route("/", module),
      new Hono<AuthorizationEnv>(),
    )
    : undefined;

  return { combinedRoutes, turnstile, billingWebhooks };
}

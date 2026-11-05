import { type Context, Hono, type MiddlewareHandler } from "hono";
import { V1DownloadIntentRequest, v1Route } from "@studafy/contracts";
import type { Sql } from "@studafy/database";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import { requirePermission } from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { committedJson, idempotency } from "../platform/idempotency";
import { problem } from "../platform/errors";
import {
  routeParam,
  validatedBody,
  validateRouteInput,
} from "../platform/validation";
import {
  membershipDbContext,
  type RequestDbContext,
  withRequestContext,
} from "../platform/dbContext";
import type { CatalogueCommandResult } from "../platform/dispatchRepository";
import { outcomeProblem, type OutcomeTable } from "../platform/outcomes";
import { requireStudentLookupChallenge } from "../turnstile/middleware";
import type { TurnstileOptions } from "../turnstile/verification";
import { type DeliveryConfig, mintDeliveryLink } from "../files/routes";

type QueryOperation =
  | "orgs"
  | "myInvites"
  | "myLinks"
  | "dashboard"
  | "teachers"
  | "classes"
  | "roster"
  | "lessons"
  | "assignments"
  | "handIns"
  | "tests"
  | "testAnswers"
  | "marks"
  | "attendance"
  | "wellbeing"
  | "overview"
  | "student"
  | "teacher"
  | "reports";
type CommandOperation =
  | "createOrg"
  | "updateOrg"
  | "closeOrg"
  | "inviteAdmin"
  | "acceptInvite"
  | "removeAdmin"
  | "requestLink"
  | "cancelLink"
  | "decideLink"
  | "endLink"
  | "reportOrg"
  | "recordExport";

/**
 * Studafy School Portal (api062, docs/planning/school-portal.md). Every call
 * runs as the requesting user with no school context: the SQL re-checks on
 * each call that the caller is a live administrator of an active school, or
 * the teacher a link names, and that a class belongs to a teacher linked
 * with the school at that moment. Every read is written to the activity
 * record. Nothing here changes a class.
 */
export interface SchoolPortalRepository {
  query(
    context: RequestDbContext,
    operation: QueryOperation,
    resourceId: string | null,
    orgId: string | null,
  ): Promise<Record<string, unknown>>;
  command(
    context: RequestDbContext,
    operation: CommandOperation,
    resourceId: string | null,
    body: Record<string, unknown>,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult & { reason?: string }>;
  /** A FILE-051 download grant for a file of a linked teacher's class. */
  fileDownload(
    context: RequestDbContext,
    orgId: string,
    fileId: string,
    internal: {
      nonceHash: string;
      downloadUrl: string;
      expiresAt: string;
      variant: "original" | "preview";
    },
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult>;
}

export class PostgresSchoolPortalRepository implements SchoolPortalRepository {
  constructor(readonly sql: Sql) {}

  async query(
    context: RequestDbContext,
    operation: QueryOperation,
    resourceId: string | null,
    orgId: string | null,
  ): Promise<Record<string, unknown>> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: Record<string, unknown> }[]>`
        select private.api062_query(
          ${operation}, ${resourceId}::uuid,
          ${tx.json({ orgId } as never)}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }

  async command(
    context: RequestDbContext,
    operation: CommandOperation,
    resourceId: string | null,
    body: Record<string, unknown>,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult & { reason?: string }> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<
        { result: CatalogueCommandResult & { reason?: string } }[]
      >`
        select private.api062_command(
          ${operation}, ${resourceId}::uuid, ${tx.json({ body } as never)},
          ${reservation.id}::uuid, ${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }

  async fileDownload(
    context: RequestDbContext,
    orgId: string,
    fileId: string,
    internal: Record<string, string>,
    reservation: { id: string; generation: number },
  ): Promise<CatalogueCommandResult> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: CatalogueCommandResult }[]>`
        select private.api062_file_download(
          ${orgId}::uuid, ${fileId}::uuid, ${tx.json(internal as never)},
          ${reservation.id}::uuid, ${reservation.generation}
        ) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
}

export interface SchoolPortalRoutesDependencies {
  repository: SchoolPortalRepository;
  /** SCHOOL_PORTAL_ENABLED. Off, every route answers 404. */
  enabled: boolean;
  /** Creating a school and finding a teacher need a solved challenge. */
  turnstile?: TurnstileOptions;
  /** FILE-051 delivery; without it files are listed but cannot be opened. */
  delivery?: DeliveryConfig | null;
}

/** Refusals particular to the portal; a conflict carries its reason. */
const PORTAL_REFUSALS: OutcomeTable = {
  rate_limited: ["RATE_LIMITED", 429],
  teacher_not_found: ["TEACHER_NOT_FOUND", 404],
  admin_limit: ["SCHOOL_ADMIN_LIMIT", 409],
  already_admin: ["ALREADY_ADMIN", 409],
  already_requested: ["SCHOOL_LINK_EXISTS", 409],
  recently_declined: ["SCHOOL_LINK_RECENTLY_DECLINED", 409],
  teacher_busy: ["TEACHER_REQUESTS_FULL", 409],
  linked_elsewhere: ["LINKED_ELSEWHERE", 409],
  school_unavailable: ["SCHOOL_UNAVAILABLE", 409],
  already_reported: ["ALREADY_REPORTED", 409],
  not_pending: ["INVALID_STATE", 409],
  not_linked: ["INVALID_STATE", 409],
  file_not_clean: ["FILE_NOT_CLEAN", 409],
  preview_unavailable: ["NOT_FOUND", 404],
};

/** The portal never acts inside a school of the request's choosing. */
function selfContext(c: Context<AuthorizationEnv>): RequestDbContext {
  return { ...membershipDbContext(c), schoolId: null };
}

type Schema = {
  safeParse: (v: unknown) => { success: boolean; data?: unknown };
};

export function createSchoolPortalRoutes(
  deps: SchoolPortalRoutesDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const log = authorization.logger;

  // Off, the portal does not exist: 404 before permission or idempotency.
  const switchedOn: MiddlewareHandler<AuthorizationEnv> = async (c, next) => {
    if (!deps.enabled) return problem(c, "NOT_FOUND", 404);
    await next();
  };
  routes.use("/v1/school-portal/*", switchedOn);
  routes.use("/v1/me/school-links", switchedOn);
  routes.use("/v1/me/school-links/*", switchedOn);
  if (deps.turnstile) {
    const challenge = requireStudentLookupChallenge(deps.turnstile);
    routes.post("/v1/school-portal/orgs", challenge);
    routes.post("/v1/school-portal/orgs/:orgId/link-requests", challenge);
  }

  function refusal(
    c: Context<AuthorizationEnv>,
    result: { outcome: string; reason?: string },
  ): Response {
    const key = result.outcome === "conflict" && result.reason
      ? result.reason
      : result.outcome;
    return outcomeProblem(c, key, PORTAL_REFUSALS, log);
  }

  async function read(
    c: Context<AuthorizationEnv>,
    operation: QueryOperation,
    schema: Schema,
    resourceId: string | null = null,
    orgId: string | null = null,
  ): Promise<Response> {
    const result = await deps.repository.query(
      selfContext(c),
      operation,
      resourceId,
      orgId,
    );
    if (result["outcome"] !== "ok") {
      return refusal(c, {
        outcome: String(result["outcome"] ?? "not_found"),
      });
    }
    const { outcome: _outcome, ...rest } = result;
    const parsed = schema.safeParse(rest);
    if (!parsed.success) {
      log.error("school_portal_response_invalid", { operation });
      return problem(c, "INTERNAL_ERROR", 500);
    }
    return c.json(parsed.data as never);
  }

  async function write(
    c: Context<AuthorizationEnv>,
    operation: CommandOperation,
    resourceId: string | null,
    body: Record<string, unknown>,
    schema: Schema,
  ): Promise<Response> {
    const reservation = c.get("idempotencyReservation");
    if (!reservation) return problem(c, "FORBIDDEN", 403);
    const { captchaToken: _captcha, ...rest } = body;
    const result = await deps.repository.command(
      selfContext(c),
      operation,
      resourceId,
      rest,
      reservation,
    );
    if (result.outcome !== "ok") return refusal(c, result);
    const parsed = schema.safeParse(result.response);
    if (!parsed.success) {
      log.error("school_portal_response_invalid", { operation });
      return problem(c, "INTERNAL_ERROR", 500);
    }
    const status = (result as { status?: number }).status === 201 ? 201 : 200;
    return committedJson(c, parsed.data as never, status);
  }

  /** GET routes: one SQL read each; `org` and `id` name route params. */
  function get(
    operationId: Parameters<typeof v1Route>[0],
    path: string,
    operation: QueryOperation,
    permission: "school_portal.read" | "school_link.read",
    id?: string,
  ) {
    const route = v1Route(operationId);
    routes.get(
      path,
      validateRouteInput(route),
      requirePermission(authorization, permission),
      async (c) =>
        await read(
          c,
          operation,
          route.response,
          id ? routeParam(c, id) : null,
          path.includes(":orgId") ? routeParam(c, "orgId") : null,
        ),
    );
  }

  /** POST routes: one SQL command each, behind an idempotency key. */
  function post(
    operationId: Parameters<typeof v1Route>[0],
    path: string,
    operation: CommandOperation,
    permission:
      | "school_portal.manage"
      | "school_portal.read"
      | "school_link.manage",
    id?: string,
  ) {
    const route = v1Route(operationId);
    routes.post(
      path,
      validateRouteInput(route),
      requirePermission(authorization, permission),
      idempotency(idempotencyDependencies, route.operationId, "required"),
      async (c) =>
        await write(
          c,
          operation,
          id ? routeParam(c, id) : null,
          validatedBody<Record<string, unknown>>(c),
          route.response,
        ),
    );
  }

  const ORG = "/v1/school-portal/orgs/:orgId";
  const read_ = "school_portal.read" as const;
  const manage = "school_portal.manage" as const;

  // In catalogue order (the mounting test compares them).
  get("listSchoolPortalOrgs", "/v1/school-portal/orgs", "orgs", read_);
  post("createSchoolPortalOrg", "/v1/school-portal/orgs", "createOrg", manage);
  post("updateSchoolPortalOrg", ORG, "updateOrg", manage, "orgId");
  post("closeSchoolPortalOrg", `${ORG}/close`, "closeOrg", manage, "orgId");
  post(
    "inviteSchoolPortalAdmin",
    `${ORG}/admins`,
    "inviteAdmin",
    manage,
    "orgId",
  );
  post(
    "removeSchoolPortalAdmin",
    `${ORG}/admins/remove`,
    "removeAdmin",
    manage,
    "orgId",
  );
  get(
    "listMySchoolPortalInvites",
    "/v1/school-portal/invites",
    "myInvites",
    read_,
  );
  post(
    "acceptSchoolPortalInvite",
    "/v1/school-portal/invites/:inviteId/accept",
    "acceptInvite",
    manage,
    "inviteId",
  );
  get(
    "getSchoolPortalDashboard",
    `${ORG}/dashboard`,
    "dashboard",
    read_,
    "orgId",
  );
  get(
    "listSchoolPortalTeachers",
    `${ORG}/teachers`,
    "teachers",
    read_,
    "orgId",
  );
  post(
    "requestSchoolPortalLink",
    `${ORG}/link-requests`,
    "requestLink",
    manage,
    "orgId",
  );
  post(
    "cancelSchoolPortalLink",
    `${ORG}/link-requests/:linkId/cancel`,
    "cancelLink",
    manage,
    "linkId",
  );
  post(
    "unlinkSchoolPortalTeacher",
    `${ORG}/teachers/:linkId/unlink`,
    "endLink",
    manage,
    "linkId",
  );
  get("listSchoolPortalClasses", `${ORG}/classes`, "classes", read_, "orgId");
  const CLASS = `${ORG}/classes/:classroomId`;
  get(
    "listSchoolPortalRoster",
    `${CLASS}/roster`,
    "roster",
    read_,
    "classroomId",
  );
  get(
    "listSchoolPortalLessons",
    `${CLASS}/lessons`,
    "lessons",
    read_,
    "classroomId",
  );
  get(
    "listSchoolPortalAssignments",
    `${CLASS}/assignments`,
    "assignments",
    read_,
    "classroomId",
  );
  get(
    "listSchoolPortalHandIns",
    `${ORG}/assignments/:assignmentId/hand-ins`,
    "handIns",
    read_,
    "assignmentId",
  );
  get("listSchoolPortalTests", `${CLASS}/tests`, "tests", read_, "classroomId");
  get(
    "listSchoolPortalTestAnswers",
    `${ORG}/tests/:assessmentId/answers`,
    "testAnswers",
    read_,
    "assessmentId",
  );
  get("listSchoolPortalMarks", `${CLASS}/marks`, "marks", read_, "classroomId");
  get(
    "listSchoolPortalAttendance",
    `${CLASS}/attendance`,
    "attendance",
    read_,
    "classroomId",
  );
  get(
    "listSchoolPortalWellbeing",
    `${CLASS}/wellbeing`,
    "wellbeing",
    read_,
    "classroomId",
  );
  get(
    "listMySchoolLinks",
    "/v1/me/school-links",
    "myLinks",
    "school_link.read",
  );
  post(
    "decideMySchoolLink",
    "/v1/me/school-links/:linkId/decision",
    "decideLink",
    "school_link.manage",
    "linkId",
  );
  post(
    "unlinkMySchool",
    "/v1/me/school-links/:linkId/unlink",
    "endLink",
    "school_link.manage",
    "linkId",
  );
  post(
    "reportMySchoolLink",
    "/v1/me/school-links/:linkId/report",
    "reportOrg",
    "school_link.manage",
    "linkId",
  );

  // Opening a file: a single-use link on the FILE-051 delivery route, which
  // re-checks the portal's rule when it is used. The link is minted here and
  // disclosed only after the grant has committed.
  const download = v1Route("createSchoolPortalFileDownload");
  routes.post(
    `${ORG}/files/:fileId/download-intent`,
    validateRouteInput(download),
    requirePermission(authorization, "school_portal.read"),
    idempotency(idempotencyDependencies, download.operationId, "required"),
    async (c) => {
      const delivery = deps.delivery;
      if (!delivery) return problem(c, "FILE_DELIVERY_DISABLED", 409);
      const reservation = c.get("idempotencyReservation");
      if (!reservation) return problem(c, "FORBIDDEN", 403);
      const fileId = routeParam(c, "fileId");
      const variant =
        V1DownloadIntentRequest.parse(validatedBody(c) ?? {}).variant ??
          "original";
      const result = await deps.repository.fileDownload(
        selfContext(c),
        routeParam(c, "orgId"),
        fileId,
        await mintDeliveryLink(
          delivery,
          fileId,
          c.get("actor").token.subject,
          variant,
        ),
        reservation,
      );
      if (result.outcome !== "ok") return refusal(c, result);
      const parsed = download.response.safeParse(result.response);
      if (!parsed.success) return problem(c, "INTERNAL_ERROR", 500);
      return committedJson(c, parsed.data);
    },
  );

  // Version 1 additions (plan 13a), after the file route in the catalogue.
  get("getSchoolPortalOverview", `${ORG}/overview`, "overview", read_, "orgId");
  get(
    "getSchoolPortalStudent",
    `${ORG}/students/:studentId`,
    "student",
    read_,
    "studentId",
  );
  get(
    "getSchoolPortalTeacher",
    `${ORG}/teachers/:teacherId`,
    "teacher",
    read_,
    "teacherId",
  );
  get("listSchoolPortalReports", `${ORG}/reports`, "reports", read_, "orgId");
  post(
    "recordSchoolPortalExport",
    `${ORG}/exports`,
    "recordExport",
    "school_portal.read",
    "orgId",
  );

  return routes;
}

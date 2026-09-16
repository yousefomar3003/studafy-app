import type { Context, Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { createCatalogueRoutes } from "../platform/catalogueRoutes";
import type { AcademicRepository } from "./repository";

export interface AcademicDependencies {
  repository: AcademicRepository;
  cursorSigningKey: string;
  enabledSlices?: Partial<Record<AcademicSlice, boolean>>;
}

export type AcademicSlice =
  | "classes"
  | "content"
  | "assignments"
  | "assessments"
  | "grades"
  | "attendance"
  | "wellbeing";

// Bounded, not open-ended: entries after index 51 belong to school-admin
// (API-042 S1) and are mounted by createSchoolAdminRoutes instead.
const ACADEMIC_ROUTES = V1_ROUTE_CATALOGUE.slice(12, 52);

function selector(
  c: Context<AuthorizationEnv>,
  route: { path: string; permission: string },
): string | null {
  const params = (c.get("validatedParams") ?? {}) as Record<string, string>;
  const query = (c.get("validatedQuery") ?? {}) as Record<string, string>;
  const body = (c.get("validatedBody") ?? {}) as Record<string, unknown>;
  return params["gradeResultId"] ?? params["assessmentId"] ??
    params["assignmentId"] ??
    params["resourceId"] ?? params["classroomId"] ?? params["schoolId"] ??
    query["classroomId"] ?? query["studentId"] ?? query["schoolId"] ??
    (typeof body["classroomId"] === "string" ? body["classroomId"] : null) ??
    (typeof body["schoolId"] === "string" ? body["schoolId"] : null) ??
    (route.permission === "school.read" ? params["schoolId"] ?? null : null);
}

function sliceFor(operation: string): AcademicSlice {
  if (/School|Term|Classroom/.test(operation)) return "classes";
  if (/Resource|LessonSession/.test(operation)) return "content";
  if (/Assignment|Submission/.test(operation)) return "assignments";
  if (/Assessment/.test(operation)) return "assessments";
  if (/Attendance/.test(operation)) return "attendance";
  if (/Wellbeing/.test(operation)) return "wellbeing";
  return "grades";
}

export function createAcademicRoutes(
  deps: AcademicDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: ACADEMIC_ROUTES,
      repository: deps.repository,
      cursorSigningKey: deps.cursorSigningKey,
      selector,
      sliceFor,
      enabledSlices: deps.enabledSlices,
    },
    authorization,
    idempotencyDependencies,
  );
}

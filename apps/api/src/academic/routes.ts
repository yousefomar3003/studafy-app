import type { Context, Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import {
  catalogueRoutesNamed,
  createCatalogueRoutes,
} from "../platform/catalogueRoutes";
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
const ACADEMIC_ROUTES = catalogueRoutesNamed([
  "getSchool",
  "listTerms",
  "listClassrooms",
  "createClassroom",
  "getClassroom",
  "listClassroomStaff",
  "updateClassroom",
  "replaceClassroomSchedule",
  "listClassroomStudents",
  "listResources",
  "listLessonSessions",
  "createResource",
  "reviseResource",
  "publishResource",
  "withdrawResource",
  "listAssignments",
  "createAssignment",
  "publishAssignment",
  "withdrawAssignment",
  "submitAssignment",
  "getAssignment",
  "listAssignmentSubmissions",
  "listAssessments",
  "createAssessment",
  "publishAssessment",
  "withdrawAssessment",
  "listAssessmentQuestions",
  "listAssessmentAuthoringQuestions",
  "listAssessmentAttempts",
  "submitAssessment",
  "listGradeResults",
  "reviewGradeResult",
  "publishGradeResult",
  "correctGradeResult",
  "withdrawGradeResult",
  "listAttendance",
  "listAttendanceRoster",
  "recordAttendance",
  "listWellbeing",
  "createWellbeing",
]);

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

/// Academic operations appended after the index-based block above.
///
/// Selected by operation id: ACADEMIC_ROUTES is a positional slice, so a
/// route appended at the end of the catalogue would never be picked up by it.
const ACADEMIC_APPENDED_OPERATIONS = new Set(["closeLessonSession"]);
const ACADEMIC_APPENDED_ROUTES = V1_ROUTE_CATALOGUE.filter((route) =>
  ACADEMIC_APPENDED_OPERATIONS.has(route.operationId)
);

function appendedSelector(c: Context<AuthorizationEnv>): string | null {
  const params = (c.get("validatedParams") ?? {}) as Record<string, string>;
  return params["lessonSessionId"] ?? null;
}

export function createAcademicAppendedRoutes(
  deps: AcademicDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: ACADEMIC_APPENDED_ROUTES,
      repository: deps.repository,
      cursorSigningKey: deps.cursorSigningKey,
      selector: appendedSelector,
      sliceFor: () => "classes" as AcademicSlice,
      enabledSlices: deps.enabledSlices,
    },
    authorization,
    idempotencyDependencies,
  );
}

/** Deleting (archiving) a class, mounted last as it is last in the
 * catalogue. The SQL behind it keeps students' notebooks. */
export function createClassroomArchiveRoutes(
  deps: AcademicDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: catalogueRoutesNamed(["archiveClassroom"]),
      repository: deps.repository,
      cursorSigningKey: deps.cursorSigningKey,
      selector: (c) =>
        ((c.get("validatedParams") ?? {}) as Record<string, string>)[
          "classroomId"
        ] ?? null,
      sliceFor: () => "classes" as AcademicSlice,
      enabledSlices: deps.enabledSlices,
    },
    authorization,
    idempotencyDependencies,
  );
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

/// Submission history: every attempt at one assignment.
///
/// Its own group because it sits at the very end of the contract catalogue,
/// and mount order is asserted to equal catalogue order - it must be mounted
/// after everything the catalogue lists before it.
const SUBMISSION_HISTORY_ROUTES = V1_ROUTE_CATALOGUE.filter((route) =>
  route.operationId === "listSubmissionHistory"
);

export function createSubmissionHistoryRoutes(
  deps: AcademicDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: SUBMISSION_HISTORY_ROUTES,
      repository: deps.repository,
      cursorSigningKey: deps.cursorSigningKey,
      selector: (c) =>
        ((c.get("validatedParams") ?? {}) as Record<string, string>)[
          "assignmentId"
        ] ?? null,
      sliceFor: () => "assignments" as AcademicSlice,
      enabledSlices: deps.enabledSlices,
    },
    authorization,
    idempotencyDependencies,
  );
}

/// Paper gradebook, attendance corrections, deadlines and editing
/// (2026-09-30). Appended at the very end of the contract catalogue, so
/// mounted last.
const COURSEWORK_OPERATIONS = new Set([
  "listGradebook",
  "saveGradeDrafts",
  "publishGrades",
  "correctGrades",
  "updateGradebookItem",
  "listGradeHistory",
  "correctAttendance",
  "listAttendanceHistory",
  "listAssignmentExtensions",
  "grantAssignmentExtension",
  "revokeAssignmentExtension",
  "reopenAssignment",
  "updateAssignmentMaterials",
  "updateAssessmentMaterials",
  "editResource",
]);
const COURSEWORK_ROUTES = V1_ROUTE_CATALOGUE.filter((route) =>
  COURSEWORK_OPERATIONS.has(route.operationId)
);

function courseworkSlice(operation: string): AcademicSlice {
  if (/Attendance/.test(operation)) return "attendance";
  if (/Assignment/.test(operation)) return "assignments";
  if (/AssessmentMaterials/.test(operation)) return "assessments";
  if (/Resource/.test(operation)) return "content";
  return "grades";
}

export function createCourseworkRoutes(
  deps: AcademicDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: COURSEWORK_ROUTES,
      repository: deps.repository,
      cursorSigningKey: deps.cursorSigningKey,
      // Every route names exactly one resource in its path.
      selector: (c) => {
        const params = (c.get("validatedParams") ?? {}) as Record<
          string,
          string
        >;
        return params["assessmentId"] ?? params["gradeResultId"] ??
          params["lessonSessionId"] ?? params["assignmentId"] ??
          params["resourceId"] ?? params["schoolId"] ?? null;
      },
      sliceFor: courseworkSlice,
      enabledSlices: deps.enabledSlices,
    },
    authorization,
    idempotencyDependencies,
  );
}

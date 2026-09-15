import type { Context, Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type { AuthorizationDependencies, AuthorizationEnv } from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { createCatalogueRoutes } from "../platform/catalogueRoutes";
import type { SchoolAdminRepository } from "./repository";

export interface SchoolAdminDependencies {
  repository: SchoolAdminRepository;
  cursorSigningKey: string;
  enabledSlices?: Partial<Record<SchoolAdminSlice, boolean>>;
}

export type SchoolAdminSlice = "schools" | "memberships" | "staffing" | "enrollment";

// School-admin owns the fixed slice of the catalogue appended after
// academic (indices 52-63); academic/routes.ts bounds its own slice to
// [12, 52) so the two modules never claim the same entries.
const SCHOOL_ADMIN_ROUTES = V1_ROUTE_CATALOGUE.slice(52, 64);

function selector(
  c: Context<AuthorizationEnv>,
): string | null {
  const params = (c.get("validatedParams") ?? {}) as Record<string, string>;
  return params["schoolId"] ?? params["membershipId"] ?? params["classroomId"] ?? null;
}

function sliceFor(operation: string): SchoolAdminSlice {
  if (/School/.test(operation)) return "schools";
  if (/Membership/.test(operation)) return "memberships";
  if (/ClassroomStaff/.test(operation)) return "staffing";
  return "enrollment";
}

export function createSchoolAdminRoutes(
  deps: SchoolAdminDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: SCHOOL_ADMIN_ROUTES,
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

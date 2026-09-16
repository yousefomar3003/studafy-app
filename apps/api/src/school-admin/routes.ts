import type { Context, Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type { AuthorizationDependencies, AuthorizationEnv } from "../authorization/middleware";
import type { AuthDependencies } from "../auth/middleware";
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

// createTerm/createStudent (indices [94, 96)) were appended after every
// other module's slice - see the comment in
// packages/contracts/src/v1/routes.ts - rather than inserted into this
// module's contiguous [52, 64) range, so this is a second small router
// instead of a second range on SCHOOL_ADMIN_ROUTES. The mounted-route order
// AUTH-031's parity test checks must match V1_ROUTE_CATALOGUE's own order,
// and this module is mounted right after academic - long before the
// catalogue reaches index 94 - so folding them into SCHOOL_ADMIN_ROUTES
// would desync the two orderings. apps/api/src/index.ts mounts this last,
// after every other module, to match.
const SCHOOL_ROSTER_ROUTES = V1_ROUTE_CATALOGUE.slice(94, 96);

function rosterSelector(c: Context<AuthorizationEnv>): string | null {
  const params = (c.get("validatedParams") ?? {}) as Record<string, string>;
  return params["schoolId"] ?? null;
}

export function createSchoolRosterRoutes(
  deps: SchoolAdminDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: SCHOOL_ROSTER_ROUTES,
      repository: deps.repository,
      cursorSigningKey: deps.cursorSigningKey,
      selector: rosterSelector,
      sliceFor: () => "schools",
      enabledSlices: deps.enabledSlices,
    },
    authorization,
    idempotencyDependencies,
  );
}

export function createSchoolAdminRoutes(
  deps: SchoolAdminDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
  authDependencies: AuthDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: SCHOOL_ADMIN_ROUTES,
      repository: deps.repository,
      cursorSigningKey: deps.cursorSigningKey,
      selector,
      sliceFor,
      enabledSlices: deps.enabledSlices,
      // instructions.md section 7: school closure/suspension are admin
      // mutations sensitive enough to require a fresh re-confirmation, not
      // just the platform-operator/school-admin role check the SQL
      // dispatcher already enforces. Both reuse AUTH-030's
      // 'school_admin_privileged' purpose, reserved for exactly this since
      // supabase/migrations/202609130003_auth030_reauth_grants.sql.
      //
      // Deliberately not requireAal2() here: ReauthRequirement.aal2 gates on
      // Actor.mfaRequiredByPolicy, which is derived only from the actor's
      // own public.memberships rows (apps/api/src/auth/middleware.ts). A
      // platform operator - the actual actor for both of these - never has
      // a membership at the school they are closing, so that check would
      // silently never fire for the one actor type it is meant to cover.
      // Support-access sidesteps this the same "no memberships row" gap
      // documents throughout API-042 by checking aal2 unconditionally in
      // its own SQL dispatcher instead (support-access/repository.ts);
      // adding it here as requireAal2() would be a control that reads as
      // real but is not.
      reauth: {
        dependencies: authDependencies,
        requirements: {
          closeSchool: { purpose: "school_admin_privileged" },
          suspendSchool: { purpose: "school_admin_privileged" },
        },
      },
    },
    authorization,
    idempotencyDependencies,
  );
}

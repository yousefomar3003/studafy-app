import { type Context, Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { createCatalogueRoutes } from "../platform/catalogueRoutes";
import type { TurnstileOptions } from "../turnstile/verification";
import { requireStudentLookupChallenge } from "../turnstile/middleware";
import type { FamilyRepository } from "./repository";

export interface FamilyDependencies {
  repository: FamilyRepository;
  turnstile?: TurnstileOptions;
  cursorSigningKey: string;
  enabledSlices?: Partial<Record<FamilySlice, boolean>>;
}

export type FamilySlice = "family";

// Appended after invitations' 4 entries (indices [64, 68)).
const FAMILY_ROUTES = V1_ROUTE_CATALOGUE.slice(68, 72);
// DL-050 appended listMyGuardianLinks at the end of the catalogue; it
// mounts in its own router so handler order stays equal to the contract.
const FAMILY_READ_ROUTES = V1_ROUTE_CATALOGUE.filter((route) =>
  route.operationId === "listMyGuardianLinks"
);

function selector(c: Context<AuthorizationEnv>): string | null {
  const params = (c.get("validatedParams") ?? {}) as Record<string, string>;
  return params["guardianLinkId"] ?? null;
}

function sliceFor(): FamilySlice {
  return "family";
}

export function createFamilyRoutes(
  deps: FamilyDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const router = new Hono<AuthorizationEnv>();
  if (deps.turnstile) {
    router.use(
      "/v1/students/locate",
      requireStudentLookupChallenge(deps.turnstile),
    );
  }
  router.route(
    "/",
    createCatalogueRoutes(
      {
        routes: FAMILY_ROUTES,
        repository: deps.repository,
        cursorSigningKey: deps.cursorSigningKey,
        selector,
        sliceFor,
        enabledSlices: deps.enabledSlices,
      },
      authorization,
      idempotencyDependencies,
    ),
  );
  return router;
}

export function createFamilyReadRoutes(
  deps: FamilyDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: FAMILY_READ_ROUTES,
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

export function createStudentFamilyRoutes(
  deps: FamilyDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: V1_ROUTE_CATALOGUE.filter((route) =>
        ["getStudentFamily", "decideGuardianLink"].includes(route.operationId)
      ),
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

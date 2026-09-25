import type { Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { createCatalogueRoutes } from "../platform/catalogueRoutes";
import type { OnboardingRepository } from "./repository";

export interface OnboardingDependencies {
  repository: OnboardingRepository;
  cursorSigningKey: string;
  enabledSlices?: Partial<Record<OnboardingSlice, boolean>>;
  /** Clears the caller's cached session context once they have a membership. */
  invalidateActorContext?: (subject: string) => Promise<void>;
}

export type OnboardingSlice = "onboarding";

const ONBOARDING_OPERATIONS = new Set(["createTeacherWorkspace"]);

// Selected by operation id, not by array index, for the reason JOIN-052
// states: a positional slice silently remounts the wrong handlers as soon as
// a route is appended above it.
const ONBOARDING_ROUTES = V1_ROUTE_CATALOGUE.filter((route) =>
  ONBOARDING_OPERATIONS.has(route.operationId)
);

// The caller has no school and no resource: being signed in is the whole
// permission, and the command itself refuses an account that already has a
// membership.
function selector(): string | null {
  return null;
}

function sliceFor(): OnboardingSlice {
  return "onboarding";
}

export function createOnboardingRoutes(
  deps: OnboardingDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: ONBOARDING_ROUTES,
      repository: deps.repository,
      cursorSigningKey: deps.cursorSigningKey,
      selector,
      sliceFor,
      enabledSlices: deps.enabledSlices,
      // This command exists to give the caller their first membership, so
      // their cached context is wrong the instant it succeeds.
      ...(deps.invalidateActorContext
        ? {
          actorContextChangedBy: {
            operations: ONBOARDING_OPERATIONS,
            invalidate: deps.invalidateActorContext,
          },
        }
        : {}),
    },
    authorization,
    idempotencyDependencies,
  );
}

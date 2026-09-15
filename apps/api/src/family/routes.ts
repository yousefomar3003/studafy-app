import type { Context, Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type { AuthorizationDependencies, AuthorizationEnv } from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { createCatalogueRoutes } from "../platform/catalogueRoutes";
import type { FamilyRepository } from "./repository";

export interface FamilyDependencies {
  repository: FamilyRepository;
  cursorSigningKey: string;
  enabledSlices?: Partial<Record<FamilySlice, boolean>>;
}

export type FamilySlice = "family";

// Appended after invitations' 4 entries (indices [64, 68)).
const FAMILY_ROUTES = V1_ROUTE_CATALOGUE.slice(68, 72);

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
  return createCatalogueRoutes(
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
  );
}

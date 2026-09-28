import type { Context, Hono } from "hono";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import {
  catalogueRoutesNamed,
  createCatalogueRoutes,
} from "../platform/catalogueRoutes";
import type { SupportAccessRepository } from "./repository";

export interface SupportAccessDependencies {
  repository: SupportAccessRepository;
  cursorSigningKey: string;
  enabledSlices?: Partial<Record<SupportAccessSlice, boolean>>;
}

export type SupportAccessSlice = "supportAccess";

// Appended after account's 3 entries (indices [86, 89)).
const SUPPORT_ACCESS_ROUTES = catalogueRoutesNamed([
  "requestSupportAccess",
  "approveSupportAccess",
  "startSupportAccess",
  "revokeSupportAccess",
  "listSupportAccessGrants",
]);

function selector(c: Context<AuthorizationEnv>): string | null {
  const params = (c.get("validatedParams") ?? {}) as Record<string, string>;
  const query = (c.get("validatedQuery") ?? {}) as Record<string, string>;
  return params["supportGrantId"] ?? query["schoolId"] ?? null;
}

function sliceFor(): SupportAccessSlice {
  return "supportAccess";
}

export function createSupportAccessRoutes(
  deps: SupportAccessDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: SUPPORT_ACCESS_ROUTES,
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

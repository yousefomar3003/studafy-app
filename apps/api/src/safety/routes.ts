import type { Context, Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { createCatalogueRoutes } from "../platform/catalogueRoutes";
import type { SafetyRepository } from "./repository";

export interface SafetyDependencies {
  repository: SafetyRepository;
  cursorSigningKey: string;
  enabledSlices?: Partial<Record<SafetySlice, boolean>>;
}

export type SafetySlice =
  | "reporting"
  | "blocks"
  | "moderation"
  | "contentControls";

// SAFE-043's routes were appended after schoolRoster at indices [96, 119)
// (see packages/contracts/src/v1/routes.ts). Order inside the catalogue is
// fixed; sliceFor maps each operation to the config flag that gates it.
const SAFETY_ROUTES = V1_ROUTE_CATALOGUE.slice(96, 119);

function selector(c: Context<AuthorizationEnv>): string | null {
  const params = (c.get("validatedParams") ?? {}) as Record<string, string>;
  const query = (c.get("validatedQuery") ?? {}) as Record<string, string>;
  return params["reportId"] ?? params["blockId"] ?? params["legalHoldId"] ??
    params["moderationGrantId"] ?? params["schoolId"] ?? query["schoolId"] ??
    null;
}

function sliceFor(operationId: string): SafetySlice {
  switch (operationId) {
    case "getContentControls":
    case "updateContentControls":
      return "contentControls";
    case "createReport":
    case "listReports":
    case "getReport":
    case "appealReport":
      return "reporting";
    case "createBlock":
    case "listBlocks":
    case "unblockUser":
      return "blocks";
    default:
      return "moderation";
  }
}

export function createSafetyRoutes(
  deps: SafetyDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: SAFETY_ROUTES,
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

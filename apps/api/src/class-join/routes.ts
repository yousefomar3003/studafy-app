import type { Context, Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { createCatalogueRoutes } from "../platform/catalogueRoutes";
import type { ClassJoinRepository } from "./repository";

export interface ClassJoinDependencies {
  repository: ClassJoinRepository;
  cursorSigningKey: string;
  enabledSlices?: Partial<Record<ClassJoinSlice, boolean>>;
  /** Clears the joiner's cached session context once they are a member. */
  invalidateActorContext?: (subject: string) => Promise<void>;
}

export type ClassJoinSlice = "classJoin";

const CLASS_JOIN_OPERATIONS = new Set([
  "getClassJoinLink",
  "createClassJoinLink",
  "revokeClassJoinLink",
  "redeemClassJoinLink",
]);

// Selected by operation id rather than by index. Every other group here
// slices the catalogue positionally, which silently remounts the wrong
// handlers the moment a route is inserted above it.
const CLASS_JOIN_ROUTES = V1_ROUTE_CATALOGUE.filter((route) =>
  CLASS_JOIN_OPERATIONS.has(route.operationId)
);

function selector(c: Context<AuthorizationEnv>): string | null {
  const params = (c.get("validatedParams") ?? {}) as Record<string, string>;
  // Redemption resolves no resource: the token in the body is the credential,
  // and the holder is not yet a member of the school it belongs to.
  return params["classroomId"] ?? params["linkId"] ?? null;
}

function sliceFor(): ClassJoinSlice {
  return "classJoin";
}

export function createClassJoinRoutes(
  deps: ClassJoinDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: CLASS_JOIN_ROUTES,
      repository: deps.repository,
      cursorSigningKey: deps.cursorSigningKey,
      selector,
      sliceFor,
      enabledSlices: deps.enabledSlices,
      // Redeeming is how a student gets their membership, so the context
      // cached a moment earlier - when they still belonged nowhere - would
      // otherwise answer the read that immediately follows.
      ...(deps.invalidateActorContext
        ? {
          actorContextChangedBy: {
            operations: new Set(["redeemClassJoinLink"]),
            invalidate: deps.invalidateActorContext,
          },
        }
        : {}),
    },
    authorization,
    idempotencyDependencies,
  );
}

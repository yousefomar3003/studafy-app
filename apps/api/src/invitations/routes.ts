import type { Context, Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { createCatalogueRoutes } from "../platform/catalogueRoutes";
import type { InvitationsRepository } from "./repository";

export interface InvitationsDependencies {
  repository: InvitationsRepository;
  cursorSigningKey: string;
  enabledSlices?: Partial<Record<InvitationsSlice, boolean>>;
}

export type InvitationsSlice = "invitations";

// Appended after school-admin's 12 entries (indices [52, 64)).
const INVITATIONS_ROUTES = V1_ROUTE_CATALOGUE.slice(64, 68);

function selector(c: Context<AuthorizationEnv>): string | null {
  const params = (c.get("validatedParams") ?? {}) as Record<string, string>;
  return params["schoolId"] ?? params["invitationId"] ?? null;
}

function sliceFor(): InvitationsSlice {
  return "invitations";
}

export function createInvitationsRoutes(
  deps: InvitationsDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: INVITATIONS_ROUTES,
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

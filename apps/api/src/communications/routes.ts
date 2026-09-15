import type { Context, Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type { AuthorizationDependencies, AuthorizationEnv } from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { createCatalogueRoutes } from "../platform/catalogueRoutes";
import type { CommunicationsRepository } from "./repository";

export interface CommunicationsDependencies {
  repository: CommunicationsRepository;
  cursorSigningKey: string;
  enabledSlices?: Partial<Record<CommunicationsSlice, boolean>>;
}

export type CommunicationsSlice = "conversations" | "announcements";

// Appended after family's 4 entries (indices [68, 72)).
const COMMUNICATIONS_ROUTES = V1_ROUTE_CATALOGUE.slice(72, 78);

function selector(c: Context<AuthorizationEnv>): string | null {
  const params = (c.get("validatedParams") ?? {}) as Record<string, string>;
  const query = (c.get("validatedQuery") ?? {}) as Record<string, string>;
  const body = (c.get("validatedBody") ?? {}) as Record<string, unknown>;
  return params["conversationId"] ?? query["schoolId"] ??
    (typeof body["classroomId"] === "string" ? body["classroomId"] : null) ??
    (typeof body["schoolId"] === "string" ? body["schoolId"] : null);
}

function sliceFor(operation: string): CommunicationsSlice {
  return /Announcement/.test(operation) ? "announcements" : "conversations";
}

export function createCommunicationsRoutes(
  deps: CommunicationsDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: COMMUNICATIONS_ROUTES,
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

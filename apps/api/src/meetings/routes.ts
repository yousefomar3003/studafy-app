import type { Context, Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type { AuthorizationDependencies, AuthorizationEnv } from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { createCatalogueRoutes } from "../platform/catalogueRoutes";
import type { MeetingsRepository } from "./repository";

export interface MeetingsDependencies {
  repository: MeetingsRepository;
  cursorSigningKey: string;
  enabledSlices?: Partial<Record<MeetingsSlice, boolean>>;
}

export type MeetingsSlice = "meetings";

// Appended after communications' 6 entries (indices [72, 78)).
const MEETINGS_ROUTES = V1_ROUTE_CATALOGUE.slice(78, 81);

function selector(c: Context<AuthorizationEnv>): string | null {
  const params = (c.get("validatedParams") ?? {}) as Record<string, string>;
  return params["classroomId"] ?? params["meetingId"] ?? null;
}

function sliceFor(): MeetingsSlice {
  return "meetings";
}

export function createMeetingsRoutes(
  deps: MeetingsDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: MEETINGS_ROUTES,
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

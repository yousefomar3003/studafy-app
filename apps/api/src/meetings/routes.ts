import type { Context, Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import {
  catalogueRoutesNamed,
  createCatalogueRoutes,
} from "../platform/catalogueRoutes";
import type { MeetingsRepository } from "./repository";

export interface MeetingsDependencies {
  repository: MeetingsRepository;
  cursorSigningKey: string;
  enabledSlices?: Partial<Record<MeetingsSlice, boolean>>;
}

export type MeetingsSlice = "meetings";

// Appended after communications' 6 entries (indices [72, 78)).
const MEETINGS_ROUTES = catalogueRoutesNamed([
  "requestMeeting",
  "cancelMeeting",
  "getMeetingStatus",
]);

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

/// The meeting list sits at the very end of the contract catalogue, so it is
/// its own group, mounted last: mount order is asserted to equal catalogue
/// order.
const MEETING_LIST_ROUTES = V1_ROUTE_CATALOGUE.filter((route) =>
  route.operationId === "listMeetings"
);

export function createMeetingListRoutes(
  deps: MeetingsDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: MEETING_LIST_ROUTES,
      repository: deps.repository,
      cursorSigningKey: deps.cursorSigningKey,
      selector: () => null,
      sliceFor,
      enabledSlices: deps.enabledSlices,
    },
    authorization,
    idempotencyDependencies,
  );
}

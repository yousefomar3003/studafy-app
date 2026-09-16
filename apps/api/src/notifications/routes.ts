import type { Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { createCatalogueRoutes } from "../platform/catalogueRoutes";
import type { NotificationsRepository } from "./repository";

export interface NotificationsDependencies {
  repository: NotificationsRepository;
  cursorSigningKey: string;
  enabledSlices?: Partial<Record<NotificationsSlice, boolean>>;
}

export type NotificationsSlice = "notifications";

// Appended after meetings' 3 entries (indices [78, 81)).
const NOTIFICATIONS_ROUTES = V1_ROUTE_CATALOGUE.slice(81, 86);

// Every operation is self-scoped with no path param at all.
function selector(): string | null {
  return null;
}

function sliceFor(): NotificationsSlice {
  return "notifications";
}

export function createNotificationsRoutes(
  deps: NotificationsDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: NOTIFICATIONS_ROUTES,
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

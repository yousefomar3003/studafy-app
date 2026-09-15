import type { Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type { AuthorizationDependencies, AuthorizationEnv } from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { createCatalogueRoutes } from "../platform/catalogueRoutes";
import type { AccountRepository } from "./repository";

export interface AccountDependencies {
  repository: AccountRepository;
  cursorSigningKey: string;
  enabledSlices?: Partial<Record<AccountSlice, boolean>>;
}

export type AccountSlice = "account";

// Appended after notifications' 5 entries (indices [81, 86)).
const ACCOUNT_ROUTES = V1_ROUTE_CATALOGUE.slice(86, 89);

// Every operation is self-scoped with no path param at all.
function selector(): string | null {
  return null;
}

function sliceFor(): AccountSlice {
  return "account";
}

export function createAccountRoutes(
  deps: AccountDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: ACCOUNT_ROUTES,
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

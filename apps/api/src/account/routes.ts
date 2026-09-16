import type { Hono } from "hono";
import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import type { AuthDependencies } from "../auth/middleware";
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
  authDependencies: AuthDependencies,
): Hono<AuthorizationEnv> {
  return createCatalogueRoutes(
    {
      routes: ACCOUNT_ROUTES,
      repository: deps.repository,
      cursorSigningKey: deps.cursorSigningKey,
      selector,
      sliceFor,
      enabledSlices: deps.enabledSlices,
      // instructions.md section 7: a data export is sensitive enough to need
      // the same fresh re-confirmation account deletion already requires
      // (AUTH-030's account_deletion purpose, apps/api/src/auth/routes.ts) -
      // a standing second factor is not additionally required here, matching
      // that precedent exactly.
      reauth: {
        dependencies: authDependencies,
        requirements: {
          requestDataExport: { purpose: "account_data_export" },
        },
      },
      // 'account_data_export' is added to AUTH-030's reauth purpose
      // allowlist by supabase/migrations/202609160010_api042_reauth_purposes.sql.
    },
    authorization,
    idempotencyDependencies,
  );
}

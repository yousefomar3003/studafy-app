import type { Sql } from "@studafy/database";
import {
  type RequestDbContext,
  withRequestContext,
} from "../platform/dbContext";

export type ManagedAccountOperation =
  | "list"
  | "can_create"
  | "register"
  | "authorize_session";

/**
 * The SQL behind managed child accounts (api048). Every call runs as the
 * requesting user, and the function re-derives who may do what from
 * auth.uid() - including refusing a managed account outright.
 */
export interface ManagedAccountRepository {
  call(
    context: RequestDbContext,
    operation: ManagedAccountOperation,
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
  /**
   * Development only: copies an identity created in the hosted project into
   * a local database, as the auth middleware does for anyone who signs in.
   * The copy carries the app metadata the register step checks.
   */
  mirrorIdentity?(identity: MirroredIdentity): Promise<void>;
}

export interface MirroredIdentity {
  id: string;
  email: string;
  displayName: string;
  guardianId: string;
}

export class PostgresManagedAccountRepository
  implements ManagedAccountRepository {
  readonly mirrorIdentity?: (identity: MirroredIdentity) => Promise<void>;

  constructor(
    readonly sql: Sql,
    options: { mirrorIdentities?: boolean } = {},
  ) {
    if (options.mirrorIdentities) {
      this.mirrorIdentity = (identity) => this.#mirror(identity);
    }
  }

  async call(
    context: RequestDbContext,
    operation: ManagedAccountOperation,
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: Record<string, unknown> }[]>`
        select private.api048_managed_accounts(${operation}, ${
        tx.json(input as never)
      }) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }

  async #mirror(identity: MirroredIdentity): Promise<void> {
    await this.sql`
      insert into auth.users (
        id, email, aud, role, email_confirmed_at, created_at, updated_at,
        instance_id, confirmation_token, recovery_token, email_change,
        email_change_token_new, email_change_token_current,
        phone_change_token, raw_app_meta_data, raw_user_meta_data)
      values (
        ${identity.id}::uuid, ${identity.email}, 'authenticated',
        'authenticated', now(), now(), now(),
        '00000000-0000-0000-0000-000000000000', '', '', '', '', '', '',
        ${this.sql.json({ studafy_managed_by: identity.guardianId })},
        ${this.sql.json({ full_name: identity.displayName })})
      on conflict (id) do nothing
    `;
  }
}

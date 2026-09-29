/**
 * Managed child accounts: the Supabase Auth side (2026-09-28).
 *
 * A child with no email or phone still needs an identity of their own to be
 * a student. This adapter creates one and, for the managing parent only,
 * issues one-time sign-ins to it. It is the only code that uses the service
 * role for this, and it can do exactly three things.
 *
 * The account's address is under `.invalid`, a domain reserved so that it
 * can never resolve (RFC 2606): no confirmation, magic link or reset can
 * ever be delivered, so nobody can sign in to it except through the parent.
 * The guardian's id goes in app metadata, which only the service role can
 * write; the database checks it before recording the account as managed.
 */
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

export const MANAGED_ACCOUNT_DOMAIN = "managed.studafy.invalid";

export class ManagedAccountError extends Error {
  constructor(readonly kind: "unavailable" | "not_managed") {
    super(`managed_account_${kind}`);
    this.name = "ManagedAccountError";
  }
}

export interface CreatedChild {
  id: string;
  /** The undeliverable address; needed only to mirror the identity. */
  email: string;
}

export interface ManagedAccountIssuer {
  /** Creates the child's account. */
  createChild(displayName: string, guardianId: string): Promise<CreatedChild>;
  /**
   * A one-time sign-in token hash for the child. Refuses an account that is
   * not a managed one, whatever the database says.
   */
  signInToken(childId: string): Promise<string>;
  /** Removes an account whose registration did not complete. */
  deleteChild(childId: string): Promise<void>;
}

export class SupabaseManagedAccountIssuer implements ManagedAccountIssuer {
  readonly #client: SupabaseClient;

  constructor(supabaseUrl: string, serviceRoleKey: string) {
    this.#client = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { "X-Client-Info": "studafy-managed-accounts" } },
    });
  }

  async createChild(
    displayName: string,
    guardianId: string,
  ): Promise<CreatedChild> {
    const email = `child-${crypto.randomUUID()}@${MANAGED_ACCOUNT_DOMAIN}`;
    const { data, error } = await this.#client.auth.admin.createUser({
      email,
      email_confirm: true,
      user_metadata: { full_name: displayName },
      app_metadata: { studafy_managed_by: guardianId },
    });
    if (error || !data.user) throw new ManagedAccountError("unavailable");
    return { id: data.user.id, email };
  }

  async signInToken(childId: string): Promise<string> {
    const { data: found, error: readError } = await this.#client.auth.admin
      .getUserById(childId);
    if (readError || !found.user) {
      throw new ManagedAccountError("unavailable");
    }
    const email = found.user.email ?? "";
    // Belt and braces: the database decided the caller manages this child,
    // but a sign-in is only ever issued for an address nobody can receive
    // mail at. An ordinary account can never be entered this way.
    if (
      !email.endsWith(`@${MANAGED_ACCOUNT_DOMAIN}`) ||
      typeof found.user.app_metadata?.["studafy_managed_by"] !== "string"
    ) {
      throw new ManagedAccountError("not_managed");
    }
    const { data, error } = await this.#client.auth.admin.generateLink({
      type: "magiclink",
      email,
    });
    const hash = data?.properties?.hashed_token;
    if (error || !hash) throw new ManagedAccountError("unavailable");
    return hash;
  }

  async deleteChild(childId: string): Promise<void> {
    const { error } = await this.#client.auth.admin.deleteUser(childId);
    if (error) throw new ManagedAccountError("unavailable");
  }
}

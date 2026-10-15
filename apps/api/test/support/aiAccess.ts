import type { Sql } from "@studafy/database";
import type { KnownName } from "@studafy/domain";
import type {
  AiAccess,
  AiAccessRepository,
  AiConsentOperation,
} from "../../src/study/aiAccess";

/**
 * A stand-in for `private.api057_ai_consent` in unit tests: every caller has
 * [access] (default "ok", a consenting student in a class) and sees [names].
 * The real decision is proven against SQL in supabase/tests and the
 * integration suites.
 */
export function fakeAiAccess(
  access: AiAccess = "ok",
  names: KnownName[] = [],
  calls: AiConsentOperation[] = [],
): AiAccessRepository {
  return {
    call: async (_context, operation) => {
      calls.push(operation);
      if (operation === "names") return { outcome: "ok", names };
      return { outcome: "ok", access, version: "2026-10-15", consent: null };
    },
  };
}

/**
 * Fixture: [userIds] have agreed to the current AI notice, as the API would
 * record it (ADR-0043). For integration suites whose subject is something
 * else; the consent itself is proven in supabase/tests/ai_access_consent.sql
 * and aiConsent.integration.test.ts.
 */
export async function consentToAi(sql: Sql, userIds: string[]): Promise<void> {
  for (const id of userIds) {
    await sql`
      insert into public.consent_records (
        user_id, purpose, policy_version, locale, policy_id, given_by, given_as)
      select ${id}::uuid, 'ai_features', p.policy_version, 'en', p.id,
        ${id}::uuid, 'self'
      from public.consent_policies p
      where p.purpose = 'ai_features' and p.locale = 'en'
      order by p.effective_at desc, p.policy_version desc
      limit 1
      on conflict (user_id, purpose, policy_version)
        do update set withdrawn_at = null`;
  }
}

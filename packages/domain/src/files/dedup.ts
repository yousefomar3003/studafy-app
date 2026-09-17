/**
 * FILE-051 school-scoped dedupe eligibility policy.
 *
 * This is the documented twin of the SQL enforcement in
 * `private.api051_finish_scan`: the database function is the authority, and
 * this module exists so unit tests can pin the policy the SQL implements.
 * The two must never drift; the ADR names this file in that contract.
 *
 * The rule set exists to keep one property true: no tenant can learn
 * anything about another tenant's objects. Dedupe never crosses schools,
 * and eligibility additionally requires the same purpose (a compatible
 * retention/security domain), both objects clean, neither under legal hold,
 * and a root — not a dependent — as the canonical source.
 */
export interface DedupeEligibilityInput {
  sameSchool: boolean;
  samePurpose: boolean;
  sameSha256: boolean;
  bothClean: boolean;
  neitherUnderLegalHold: boolean;
  /** The candidate canonical object is a root (not itself a dependent). */
  canonicalIsRoot: boolean;
  /** The incoming object is not already a dependent of something else. */
  incomingIsRoot: boolean;
}

export function isDedupeEligible(input: DedupeEligibilityInput): boolean {
  return input.sameSchool &&
    input.samePurpose &&
    input.sameSha256 &&
    input.bothClean &&
    input.neitherUnderLegalHold &&
    input.canonicalIsRoot &&
    input.incomingIsRoot;
}

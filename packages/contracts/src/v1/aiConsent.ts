import { z } from "zod";

const Timestamp = z.string().datetime({ offset: true });

/**
 * Who may use the AI study tools (ADR-0043), as the server decides it:
 *
 *   ok                         a student in a class, with a current consent
 *   not_student                a parent or teacher account
 *   no_class                   a student account with no active class
 *   consent_required           the student has not agreed to the current notice
 *   guardian_consent_required  a managed child account: the parent agrees
 */
export const V1AiAccess = z.enum([
  "ok",
  "not_student",
  "no_class",
  "consent_required",
  "guardian_consent_required",
]);
export type V1AiAccess = z.infer<typeof V1AiAccess>;

/** A current AI consent: to which notice, in which language, by whom. */
export const V1AiConsent = z.strictObject({
  version: z.string().min(1).max(128),
  locale: z.enum(["en", "ar"]),
  givenAt: Timestamp,
  /** 'guardian' when the parent who manages the account gave it. */
  givenAs: z.enum(["self", "guardian"]),
});
export type V1AiConsent = z.infer<typeof V1AiConsent>;

/** An account's AI access and consent. */
export const V1AiConsentState = z.strictObject({
  access: V1AiAccess,
  /** The notice a consent must be for now; null when none is published. */
  version: z.string().min(1).max(128).nullable(),
  consent: V1AiConsent.nullable(),
});
export type V1AiConsentState = z.infer<typeof V1AiConsentState>;

/**
 * Agreeing to the AI notice, or withdrawing. [version] and [locale] say
 * which notice was shown, and are required to agree: the server records a
 * consent only against the current published notice in that language.
 */
export const V1UpdateAiConsentRequest = z.strictObject({
  given: z.boolean(),
  version: z.string().trim().min(1).max(128).optional(),
  locale: z.enum(["en", "ar"]).optional(),
});
export type V1UpdateAiConsentRequest = z.infer<
  typeof V1UpdateAiConsentRequest
>;

import { z } from "zod";

const Id = z.string().uuid();
const Timestamp = z.string().datetime({ offset: true });

/**
 * Managed child accounts (2026-09-28).
 *
 * A parent creates a real student account for a child who has no email or
 * phone, and switches into it from their own account. The child's account
 * has no way to sign in on its own: every session for it is issued to the
 * managing parent.
 */
export const V1ManagedChild = z.strictObject({
  childId: Id,
  displayName: z.string().min(1).max(120),
  createdAt: Timestamp,
});
export type V1ManagedChild = z.infer<typeof V1ManagedChild>;

export const V1ManagedChildList = z.strictObject({
  items: z.array(V1ManagedChild).max(20),
});
export type V1ManagedChildList = z.infer<typeof V1ManagedChildList>;

export const V1CreateManagedChildRequest = z.strictObject({
  /** The child's name as their teachers will see it. */
  displayName: z.string().trim().min(1).max(120),
  /**
   * The terms the parent accepted for the child, on the create screen. The
   * server records it only against a published policy.
   */
  policyVersion: z.string().trim().min(1).max(128),
  locale: z.enum(["en", "ar"]),
});
export type V1CreateManagedChildRequest = z.infer<
  typeof V1CreateManagedChildRequest
>;

export const V1ManagedChildSessionRequest = z.strictObject({});
export type V1ManagedChildSessionRequest = z.infer<
  typeof V1ManagedChildSessionRequest
>;

/**
 * A one-time sign-in for the child, exchanged by the app with Supabase Auth
 * for a session. Single use, short-lived, and never stored by the server:
 * this route takes no idempotency key, so the response is not replayable.
 */
export const V1ManagedChildSession = z.strictObject({
  tokenHash: z.string().min(16).max(512),
});
export type V1ManagedChildSession = z.infer<typeof V1ManagedChildSession>;

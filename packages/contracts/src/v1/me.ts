import { z } from "zod";

// Inlined to avoid a circular import with the parent index (which
// re-exports this module). The values must match the shared Environment.
const environment = z.enum([
  "synthetic",
  "development",
  "staging",
  "production",
]);

/** GET /v1/me — the authenticated user's profile, memberships, and term. */
export const V1Membership = z.object({
  id: z.string().min(1),
  school_id: z.string().min(1),
  school_name: z.string().min(1),
  role: z.enum(["teacher", "parent", "student"]),
  active: z.boolean(),
});
export type V1Membership = z.infer<typeof V1Membership>;

export const V1MeResponse = z.object({
  id: z.string().min(1),
  display_name: z.string().min(1),
  email: z.string().min(1),
  memberships: z.array(V1Membership),
  environment: environment,
  active_term_id: z.string().min(1).nullable(),
});
export type V1MeResponse = z.infer<typeof V1MeResponse>;

export const V1MeError = z.object({
  error: z.object({
    code: z.enum(["UNAUTHORIZED", "FORBIDDEN", "INTERNAL_ERROR"]),
    message: z.string().min(1),
    request_id: z.string().min(1),
  }),
});
export type V1MeError = z.infer<typeof V1MeError>;

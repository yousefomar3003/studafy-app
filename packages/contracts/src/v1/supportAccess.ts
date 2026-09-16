import { z } from "zod";

const Id = z.string().uuid();
const Version = z.number().int().positive();

export const V1SupportAccessGrant = z.strictObject({
  id: Id,
  schoolId: Id,
  requestedBy: Id,
  approvedBy: Id.nullable(),
  reason: z.string(),
  ticketRef: z.string(),
  resourceScope: z.record(z.string(), z.unknown()),
  status: z.enum(["pending", "approved", "active", "expired", "revoked", "denied"]),
  requiresSecondApprover: z.boolean(),
  expiresAt: z.string().datetime({ offset: true }),
  startedAt: z.string().datetime({ offset: true }).nullable(),
  endedAt: z.string().datetime({ offset: true }).nullable(),
  version: Version,
});
export type V1SupportAccessGrant = z.infer<typeof V1SupportAccessGrant>;

export const V1SupportAccessGrantPage = z.strictObject({
  items: z.array(V1SupportAccessGrant),
  nextCursor: z.string().nullable(),
});
export type V1SupportAccessGrantPage = z.infer<
  typeof V1SupportAccessGrantPage
>;

export const V1RequestSupportAccessRequest = z.strictObject({
  schoolId: Id,
  reason: z.string().trim().min(8).max(2000),
  ticketRef: z.string().trim().min(1).max(200),
  resourceScope: z.record(z.string(), z.unknown()).optional(),
  requiresSecondApprover: z.boolean().default(true),
  durationMinutes: z.number().int().min(1).max(480).default(60),
});
export type V1RequestSupportAccessRequest = z.infer<
  typeof V1RequestSupportAccessRequest
>;

export const V1SupportAccessLifecycleRequest = z.strictObject({
  expectedVersion: Version,
});
export type V1SupportAccessLifecycleRequest = z.infer<
  typeof V1SupportAccessLifecycleRequest
>;

export const V1RevokeSupportAccessRequest = z.strictObject({
  expectedVersion: Version,
  reason: z.string().trim().max(2000).optional(),
});
export type V1RevokeSupportAccessRequest = z.infer<
  typeof V1RevokeSupportAccessRequest
>;

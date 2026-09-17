/**
 * Versioned job payload contracts for the BullMQ queue platform (OPS-061,
 * instructions.md §10). Payloads carry opaque identifiers only — never full
 * student records, tokens, signed URLs, or large content; workers re-fetch
 * and re-authorize current state. Each queue's payload version is bumped on
 * any incompatible change; consumers must reject unknown versions.
 *
 * The operational policy for each queue (attempts, backoff, timeouts,
 * concurrency) lives in `apps/worker/src/platform/queueInventory.ts`; this
 * module is the wire contract and the drift test keeps the two in lockstep.
 */
import { z } from "zod";

/** The §10 queue inventory. Names are stable; never rename, only deprecate. */
export const JobQueueName = z.enum([
  "notifications",
  "file-security",
  "media-processing",
  "ai-grading",
  "billing-events",
  "meeting-operations",
  "exports",
  "search-index",
  "retention-maintenance",
]);
export type JobQueueNameType = z.infer<typeof JobQueueName>;

/**
 * notifications v1. Produced only by the outbox dispatcher, so every field is
 * a projection of the durable outbox row; the worker re-reads the row (via
 * SECURITY DEFINER finish) rather than trusting the payload for state.
 */
export const NotificationsJobV1 = z.object({
  outboxId: z.number().int().min(1),
  schoolId: z.string().uuid(),
  templateKey: z.string().min(1).max(200),
  channel: z.string().min(1).max(40),
  audience: z.unknown(),
  payload: z.unknown(),
});
export type NotificationsJobV1Type = z.infer<typeof NotificationsJobV1>;

/**
 * Declared queues: contracts without processors yet. Payloads are opaque
 * identifiers; the owning slice must extend, never replace, these shapes.
 */
export const FileSecurityJobV1 = z.object({
  fileId: z.string().min(1).max(64),
  scanPolicyVersion: z.string().min(1).max(40),
});
export type FileSecurityJobV1Type = z.infer<typeof FileSecurityJobV1>;

export const MediaProcessingJobV1 = z.object({
  fileId: z.string().min(1).max(64),
  transformVersion: z.string().min(1).max(40),
});
export type MediaProcessingJobV1Type = z.infer<typeof MediaProcessingJobV1>;

export const AiGradingJobV1 = z.object({
  gradeResultId: z.string().min(1).max(64),
  fileId: z.string().min(1).max(64),
  rubricPolicyVersion: z.string().min(1).max(40),
});
export type AiGradingJobV1Type = z.infer<typeof AiGradingJobV1>;

export const BillingEventsJobV1 = z.object({
  platform: z.enum(["app_store", "play_store", "school"]),
  environment: z.enum(["synthetic", "development", "staging", "production"]),
  transactionId: z.string().min(1).max(200),
});
export type BillingEventsJobV1Type = z.infer<typeof BillingEventsJobV1>;

export const MeetingOperationsJobV1 = z.object({
  meetingId: z.string().min(1).max(64),
  command: z.enum(["create", "cancel", "reconcile"]),
});
export type MeetingOperationsJobV1Type = z.infer<typeof MeetingOperationsJobV1>;

export const ExportsJobV1 = z.object({
  exportRequestId: z.string().min(1).max(64),
  snapshotVersion: z.string().min(1).max(64),
});
export type ExportsJobV1Type = z.infer<typeof ExportsJobV1>;

export const SearchIndexJobV1 = z.object({
  entityKind: z.enum(["resource", "assignment", "classroom"]),
  entityId: z.string().min(1).max(64),
  entityVersion: z.number().int().min(1),
});
export type SearchIndexJobV1Type = z.infer<typeof SearchIndexJobV1>;

export const RetentionMaintenanceJobV1 = z.object({
  policyId: z.string().min(1).max(64),
  resourceId: z.string().min(1).max(64),
  effectiveDate: z.string().min(1).max(40),
});
export type RetentionMaintenanceJobV1Type = z.infer<
  typeof RetentionMaintenanceJobV1
>;

/**
 * Job-processing result envelope used by every processor's diagnostic log
 * (job ID + safe entity hash; never a payload dump).
 */
export const JobOutcomeV1 = z.object({
  queue: JobQueueName,
  jobId: z.string().min(1).max(200),
  outcome: z.enum(["completed", "retry", "dead_letter"]),
  errorCode: z.string().min(1).max(80).optional(),
});
export type JobOutcomeV1Type = z.infer<typeof JobOutcomeV1>;

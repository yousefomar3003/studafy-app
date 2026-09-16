import { z } from "zod";

const Id = z.string().uuid();
const Version = z.number().int().positive();
const IsoTime = z.string().datetime({ offset: true });

export const V1ReportKind = z.enum(["message", "conversation", "user"]);
export type V1ReportKind = z.infer<typeof V1ReportKind>;

export const V1ReportStatus = z.enum([
  "submitted",
  "queued",
  "under_review",
  "on_hold",
  "escalated",
  "resolved",
  "withdrawn",
]);
export type V1ReportStatus = z.infer<typeof V1ReportStatus>;

export const V1ReportResolution = z.enum([
  "upheld",
  "not_upheld",
  "partial",
  "no_action",
]);
export type V1ReportResolution = z.infer<typeof V1ReportResolution>;

export const V1ReportPriority = z.enum([
  "critical",
  "high",
  "medium",
  "low",
]);
export type V1ReportPriority = z.infer<typeof V1ReportPriority>;

/** School-level safety configuration. Returns platform defaults when the
 * school has not yet written any controls. */
export const V1ContentControls = z.strictObject({
  schoolId: Id,
  messagingEnabled: z.boolean(),
  contentFilterLevel: z.enum(["off", "moderate", "strict"]),
  classifierAssistEnabled: z.boolean(),
  supportContact: z.string().nullable(),
  slaHours: z.strictObject({
    critical: z.number().int(),
    high: z.number().int(),
    medium: z.number().int(),
    low: z.number().int(),
  }),
  version: Version,
  updatedAt: IsoTime.nullable(),
});
export type V1ContentControls = z.infer<typeof V1ContentControls>;

export const V1UpdateContentControlsRequest = z.strictObject({
  schoolId: Id,
  expectedVersion: Version,
  messagingEnabled: z.boolean().optional(),
  contentFilterLevel: z.enum(["off", "moderate", "strict"]).optional(),
  classifierAssistEnabled: z.boolean().optional(),
  supportContact: z.string().max(320).nullable().optional(),
  slaHours: z
    .strictObject({
      critical: z.number().int().min(1).max(720),
      high: z.number().int().min(1).max(720),
      medium: z.number().int().min(1).max(720),
      low: z.number().int().min(1).max(720),
    })
    .optional(),
});
export type V1UpdateContentControlsRequest = z.infer<
  typeof V1UpdateContentControlsRequest
>;

/** Reporter-facing report: the reporter's own words and the status timeline,
 * with moderator identities and notes withheld. */
export const V1Report = z.strictObject({
  id: Id,
  schoolId: Id,
  kind: V1ReportKind,
  status: V1ReportStatus,
  resolution: V1ReportResolution.nullable(),
  details: z.string(),
  priority: V1ReportPriority,
  contactConsent: z.boolean(),
  subjectUserId: Id.nullable(),
  conversationId: Id.nullable(),
  messageId: Id.nullable(),
  aupVersion: z.string().nullable(),
  createdAt: IsoTime,
  updatedAt: IsoTime,
  version: Version,
  events: z.array(
    z.strictObject({
      event: z.string(),
      at: IsoTime,
      resolution: z.string().nullable(),
    }),
  ),
});
export type V1Report = z.infer<typeof V1Report>;

export const V1ReportPage = z.strictObject({
  items: z.array(V1Report),
  nextCursor: z.string().nullable(),
});
export type V1ReportPage = z.infer<typeof V1ReportPage>;

export const V1CreateReportRequest = z.strictObject({
  schoolId: Id,
  kind: V1ReportKind,
  details: z.string().min(10).max(5000),
  messageId: Id.optional(),
  conversationId: Id.optional(),
  subjectUserId: Id.optional(),
  evidenceSnapshot: z.record(z.string(), z.unknown()).optional(),
  classifierConfidence: z.number().min(0).max(1).optional(),
  contactConsent: z.boolean().default(false),
});
export type V1CreateReportRequest = z.infer<typeof V1CreateReportRequest>;

export const V1AppealReportRequest = z.strictObject({
  expectedVersion: Version,
  reason: z.string().trim().min(8).max(2000),
});
export type V1AppealReportRequest = z.infer<typeof V1AppealReportRequest>;

export const V1Block = z.strictObject({
  id: Id,
  schoolId: Id,
  blockerId: Id,
  blockedId: Id,
  scope: z.enum(["messages", "all"]),
  reason: z.string().nullable(),
  expiresAt: IsoTime.nullable(),
  createdAt: IsoTime,
  version: Version,
});
export type V1Block = z.infer<typeof V1Block>;

export const V1BlockPage = z.strictObject({
  items: z.array(V1Block),
  nextCursor: z.string().nullable(),
});
export type V1BlockPage = z.infer<typeof V1BlockPage>;

export const V1CreateBlockRequest = z.strictObject({
  schoolId: Id,
  blockedUserId: Id,
  scope: z.enum(["messages", "all"]).default("messages"),
  reason: z.string().trim().min(1).max(2000).optional(),
  durationHours: z.number().int().min(1).max(720).optional(),
});
export type V1CreateBlockRequest = z.infer<typeof V1CreateBlockRequest>;

export const V1UnblockUserRequest = z.strictObject({
  reason: z.string().trim().max(2000).optional(),
});
export type V1UnblockUserRequest = z.infer<typeof V1UnblockUserRequest>;

/** Aggregate moderation queue health for a school. */
export const V1ModerationOverview = z.strictObject({
  schoolId: Id,
  submitted: z.number().int(),
  underReview: z.number().int(),
  onHold: z.number().int(),
  escalated: z.number().int(),
  resolved: z.number().int(),
  slaBreaches: z.number().int(),
  activeModeratorSessions: z.number().int(),
});
export type V1ModerationOverview = z.infer<typeof V1ModerationOverview>;

export const V1ModerationReport = z.strictObject({
  id: Id,
  schoolId: Id,
  kind: V1ReportKind,
  status: V1ReportStatus,
  resolution: V1ReportResolution.nullable(),
  priority: V1ReportPriority,
  assignedTo: Id.nullable(),
  details: z.string(),
  evidenceSnapshot: z.record(z.string(), z.unknown()),
  classifierConfidence: z.number().nullable(),
  aupVersion: z.string().nullable(),
  contactConsent: z.boolean(),
  subjectUserId: Id.nullable(),
  conversationId: Id.nullable(),
  messageId: Id.nullable(),
  /** Null until the report is escalated, which explicitly unmasks it. */
  reporterId: Id.nullable(),
  createdAt: IsoTime,
  updatedAt: IsoTime,
  version: Version,
  events: z.array(
    z.strictObject({
      event: z.string(),
      at: IsoTime,
      note: z.string().nullable(),
      resolution: z.string().nullable(),
    }),
  ),
  evidence: z.array(
    z.strictObject({
      id: Id,
      kind: z.enum(["message", "attachment", "note"]),
      messageId: Id.nullable(),
      attachmentFileId: Id.nullable(),
      note: z.string().nullable(),
      addedBy: Id,
      createdAt: IsoTime,
    }),
  ),
});
export type V1ModerationReport = z.infer<typeof V1ModerationReport>;

export const V1ModerationQueuePage = z.strictObject({
  items: z.array(V1ModerationReport),
  nextCursor: z.string().nullable(),
});
export type V1ModerationQueuePage = z.infer<typeof V1ModerationQueuePage>;

export const V1ReportLifecycleRequest = z.strictObject({
  expectedVersion: Version,
  note: z.string().trim().min(1).max(2000).optional(),
  assignedTo: Id.optional(),
  priority: V1ReportPriority.optional(),
});
export type V1ReportLifecycleRequest = z.infer<typeof V1ReportLifecycleRequest>;

export const V1ResolveReportRequest = z.strictObject({
  expectedVersion: Version,
  resolution: V1ReportResolution,
  note: z.string().trim().min(1).max(2000).optional(),
});
export type V1ResolveReportRequest = z.infer<typeof V1ResolveReportRequest>;

export const V1EscalateReportRequest = z.strictObject({
  expectedVersion: Version,
  note: z.string().trim().max(2000).optional(),
});
export type V1EscalateReportRequest = z.infer<typeof V1EscalateReportRequest>;

export const V1HoldReportRequest = z.strictObject({
  schoolId: Id,
  expectedVersion: Version,
  subjectUserId: Id.optional(),
  appliedTo: z.enum(["account", "user_data", "report"]).default("report"),
  reason: z.string().trim().min(8).max(2000),
  ticketRef: z.string().trim().min(1).max(200),
  accountDeletionRequestId: Id.optional(),
  expiresAt: IsoTime.optional(),
});
export type V1HoldReportRequest = z.infer<typeof V1HoldReportRequest>;

export const V1ReleaseLegalHoldRequest = z.strictObject({
  expectedVersion: Version,
  reason: z.string().trim().min(8).max(2000),
});
export type V1ReleaseLegalHoldRequest = z.infer<
  typeof V1ReleaseLegalHoldRequest
>;

export const V1AddReportEvidenceRequest = z.strictObject({
  schoolId: Id,
  kind: z.enum(["attachment", "note"]),
  attachmentFileId: Id.optional(),
  note: z.string().trim().min(1).max(4000).optional(),
});
export type V1AddReportEvidenceRequest = z.infer<
  typeof V1AddReportEvidenceRequest
>;

/** Time-bounded, MFA-gated, two-person-approved moderator session grant. */
export const V1ModerationAccessGrant = z.strictObject({
  id: Id,
  schoolId: Id,
  requestedBy: Id,
  approvedBy: Id.nullable(),
  reason: z.string(),
  ticketRef: z.string(),
  resourceScope: z.record(z.string(), z.unknown()),
  status: z.enum([
    "pending",
    "approved",
    "active",
    "expired",
    "revoked",
    "denied",
  ]),
  requiresSecondApprover: z.boolean(),
  expiresAt: IsoTime,
  startedAt: IsoTime.nullable(),
  endedAt: IsoTime.nullable(),
  version: Version,
});
export type V1ModerationAccessGrant = z.infer<typeof V1ModerationAccessGrant>;

export const V1ModerationAccessGrantPage = z.strictObject({
  items: z.array(V1ModerationAccessGrant),
  nextCursor: z.string().nullable(),
});
export type V1ModerationAccessGrantPage = z.infer<
  typeof V1ModerationAccessGrantPage
>;

export const V1RequestModerationAccessRequest = z.strictObject({
  schoolId: Id,
  reason: z.string().trim().min(8).max(2000),
  ticketRef: z.string().trim().min(1).max(200),
  resourceScope: z.record(z.string(), z.unknown()).optional(),
  requiresSecondApprover: z.boolean().default(true),
  durationMinutes: z.number().int().min(15).max(480).default(60),
});
export type V1RequestModerationAccessRequest = z.infer<
  typeof V1RequestModerationAccessRequest
>;

export const V1ModerationAccessLifecycleRequest = z.strictObject({
  expectedVersion: Version,
});
export type V1ModerationAccessLifecycleRequest = z.infer<
  typeof V1ModerationAccessLifecycleRequest
>;

export const V1RevokeModerationAccessRequest = z.strictObject({
  expectedVersion: Version,
  reason: z.string().trim().max(2000).optional(),
});
export type V1RevokeModerationAccessRequest = z.infer<
  typeof V1RevokeModerationAccessRequest
>;

/** Query filter for moderation and reporting pages. */
export const V1ModerationQueueQuery = z.strictObject({
  schoolId: Id,
  status: V1ReportStatus.optional(),
  priority: V1ReportPriority.optional(),
  cursor: z.string().min(16).max(2048).optional(),
  pageSize: z.coerce.number().int().min(1).max(100).default(50),
});
export type V1ModerationQueueQuery = z.infer<typeof V1ModerationQueueQuery>;

export const V1SchoolScopeQuery = z.strictObject({
  schoolId: Id.optional(),
  cursor: z.string().min(16).max(2048).optional(),
  pageSize: z.coerce.number().int().min(1).max(100).default(50),
});
export type V1SchoolScopeQuery = z.infer<typeof V1SchoolScopeQuery>;

/** Moderation queue/overview require an explicit school scope. */
export const V1SchoolIdQuery = z.strictObject({
  schoolId: Id,
});
export type V1SchoolIdQuery = z.infer<typeof V1SchoolIdQuery>;

export const V1ModerationAccessQuery = z.strictObject({
  schoolId: Id,
  cursor: z.string().min(16).max(2048).optional(),
  pageSize: z.coerce.number().int().min(1).max(100).default(50),
});
export type V1ModerationAccessQuery = z.infer<typeof V1ModerationAccessQuery>;

/** Legal hold record returned after an operator applies or releases one. */
export const V1LegalHold = z.strictObject({
  id: Id,
  schoolId: Id,
  subjectUserId: Id.nullable(),
  reportId: Id.nullable(),
  accountDeletionRequestId: Id.nullable(),
  appliedTo: z.enum(["account", "user_data", "report"]),
  reason: z.string(),
  ticketRef: z.string(),
  status: z.enum(["active", "released"]),
  grantedBy: Id,
  releasedBy: Id.nullable(),
  releasedReason: z.string().nullable(),
  expiresAt: IsoTime.nullable(),
  releasedAt: IsoTime.nullable(),
  createdAt: IsoTime,
  version: Version,
});
export type V1LegalHold = z.infer<typeof V1LegalHold>;

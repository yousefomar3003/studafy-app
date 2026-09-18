import { z } from "zod";
import { V1Resource } from "./academic";

const Id = z.string().uuid();
const Timestamp = z.string().datetime({ offset: true });
const Sha256 = z.string().regex(/^[0-9a-f]{64}$/);

export const V1FilePurpose = z.enum([
  "profile_image",
  "lesson_resource",
  "assignment_material",
  "assignment_submission",
  "paper_scan",
  "coach_attachment",
]);
export type V1FilePurpose = z.infer<typeof V1FilePurpose>;

/**
 * AI-072 (ADR-0026) retired `coach_attachment`: Study Coach no longer exists,
 * so no new upload may claim it. It stays in `V1FilePurpose` only so legacy
 * sessions/objects remain describable in responses.
 */
export const V1UploadablePurpose = V1FilePurpose.exclude(["coach_attachment"]);
export type V1UploadablePurpose = z.infer<typeof V1UploadablePurpose>;

export const V1UploadSessionState = z.enum([
  "initiated",
  "completed",
  "rejected",
  "expired",
  "cancelled",
]);
export type V1UploadSessionState = z.infer<typeof V1UploadSessionState>;

export const V1FileScanState = z.enum([
  "quarantined",
  "scanning",
  "clean",
  "rejected",
  "error",
  "deleted",
]);
export type V1FileScanState = z.infer<typeof V1FileScanState>;

/**
 * A single strict wire object is intentional: it gives the generated Dart
 * client useful fields while the refinement enforces the purpose-specific
 * target union. Storage location and ownership are never request fields.
 */
export const V1CreateUploadIntentRequest = z.strictObject({
  schoolId: Id,
  purpose: V1UploadablePurpose,
  displayName: z.string().min(1).max(255),
  expectedSizeBytes: z.number().int().positive().max(25 * 1024 * 1024),
  declaredMediaType: z.enum([
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/webp",
  ]),
  sha256: Sha256,
  classroomId: Id.optional(),
  assignmentId: Id.optional(),
  studentId: Id.optional(),
  gradeResultId: Id.optional(),
}).superRefine((value, context) => {
  const present = {
    classroomId: value.classroomId !== undefined,
    assignmentId: value.assignmentId !== undefined,
    studentId: value.studentId !== undefined,
    gradeResultId: value.gradeResultId !== undefined,
  };
  const required: Record<V1UploadablePurpose, (keyof typeof present)[]> = {
    profile_image: [],
    lesson_resource: ["classroomId"],
    assignment_material: ["assignmentId"],
    assignment_submission: ["assignmentId", "studentId"],
    paper_scan: ["gradeResultId"],
  };
  const allowed = new Set(required[value.purpose]);
  for (const [key, isPresent] of Object.entries(present)) {
    if (isPresent !== allowed.has(key as keyof typeof present)) {
      context.addIssue({
        code: "custom",
        path: [key],
        message: "target does not match upload purpose",
      });
    }
  }
});
export type V1CreateUploadIntentRequest = z.infer<
  typeof V1CreateUploadIntentRequest
>;

export const V1UploadSession = z.strictObject({
  id: Id,
  purpose: V1FilePurpose,
  displayName: z.string().min(1).max(255),
  declaredMediaType: z.string().min(1).max(120),
  expectedSizeBytes: z.number().int().nonnegative(),
  state: V1UploadSessionState,
  expiresAt: Timestamp,
  createdAt: Timestamp,
  completedAt: Timestamp.nullable(),
  fileId: Id.nullable(),
  failureCode: z.string().max(80).nullable(),
});
export type V1UploadSession = z.infer<typeof V1UploadSession>;

export const V1CreateUploadIntentResponse = z.strictObject({
  session: V1UploadSession,
  uploadUrl: z.string().url(),
  method: z.literal("PUT"),
  requiredHeaders: z.record(z.string(), z.string()),
  expiresAt: Timestamp,
});
export type V1CreateUploadIntentResponse = z.infer<
  typeof V1CreateUploadIntentResponse
>;

export const V1CompleteUploadRequest = z.strictObject({});
export type V1CompleteUploadRequest = z.infer<
  typeof V1CompleteUploadRequest
>;

export const V1File = z.strictObject({
  id: Id,
  purpose: V1FilePurpose,
  displayName: z.string().min(1).max(255),
  sizeBytes: z.number().int().nonnegative(),
  declaredMediaType: z.string().min(1).max(120),
  detectedMediaType: z.string().min(1).max(120).nullable(),
  scanState: V1FileScanState,
  createdAt: Timestamp,
  scannedAt: Timestamp.nullable(),
  failureCode: z.string().max(80).nullable(),
});
export type V1File = z.infer<typeof V1File>;

export const V1CompleteUploadResponse = z.strictObject({
  session: V1UploadSession,
  file: V1File,
});
export type V1CompleteUploadResponse = z.infer<
  typeof V1CompleteUploadResponse
>;

export const V1DownloadIntentRequest = z.strictObject({});
export type V1DownloadIntentRequest = z.infer<
  typeof V1DownloadIntentRequest
>;

/** Reserved now so FILE-051 can activate delivery without changing the v1 shape. */
export const V1DownloadIntentResponse = z.strictObject({
  downloadUrl: z.string().url(),
  expiresAt: Timestamp,
  displayName: z.string().min(1).max(255),
  mediaType: z.string().min(1).max(120),
});
export type V1DownloadIntentResponse = z.infer<
  typeof V1DownloadIntentResponse
>;

/**
 * FILE-051 publication. Publishing never copies bytes: one clean file object
 * becomes one resource, one immutable version and one classroom publication,
 * and access derives from that publication.
 */
export const V1PublishFileRequest = z.strictObject({
  audience: z.enum(["students", "guardians", "both"]),
});
export type V1PublishFileRequest = z.infer<typeof V1PublishFileRequest>;

export const V1PublishFileResponse = z.strictObject({
  file: V1File,
  resource: V1Resource,
});
export type V1PublishFileResponse = z.infer<typeof V1PublishFileResponse>;

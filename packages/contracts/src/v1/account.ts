import { z } from "zod";

const Id = z.string().uuid();

export const V1UpdateProfileRequest = z.strictObject({
  displayName: z.string().trim().min(1).max(160).optional(),
  locale: z.enum(["en", "ar"]).optional(),
});
export type V1UpdateProfileRequest = z.infer<typeof V1UpdateProfileRequest>;

export const V1ProfileResponse = z.strictObject({
  id: Id,
  displayName: z.string(),
  locale: z.enum(["en", "ar"]),
});
export type V1ProfileResponse = z.infer<typeof V1ProfileResponse>;

export const V1RequestDataExportRequest = z.strictObject({});
export type V1RequestDataExportRequest = z.infer<
  typeof V1RequestDataExportRequest
>;

export const V1DataExportRequest = z.strictObject({
  id: Id,
  status: z.enum(["pending", "ready", "failed", "expired"]),
  requestedAt: z.string().datetime({ offset: true }),
  readyAt: z.string().datetime({ offset: true }).nullable(),
  expiresAt: z.string().datetime({ offset: true }).nullable(),
});
export type V1DataExportRequest = z.infer<typeof V1DataExportRequest>;

export const V1ExportStatusResponse = z.strictObject({
  request: V1DataExportRequest.nullable(),
});
export type V1ExportStatusResponse = z.infer<typeof V1ExportStatusResponse>;

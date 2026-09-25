import { z } from "zod";

const Id = z.string().uuid();

/// Everything a teacher needs to start teaching, created in one call.
///
/// The product has no concept of a school, so nothing here asks the teacher
/// to name or describe one. The fields are presentation settings the client
/// already knows: the language it is rendering in and the device's time zone,
/// which decide how dates and deadlines read for every class that follows.
export const V1CreateTeacherWorkspaceRequest = z.strictObject({
  /// Defaults to the teacher's own display name. Never shown as "school".
  name: z.string().trim().min(1).max(160).optional(),
  /// IANA zone; defaults to Asia/Amman.
  timezone: z.string().trim().min(1).max(64).optional(),
  locale: z.enum(["en", "ar"]).optional(),
});
export type V1CreateTeacherWorkspaceRequest = z.infer<
  typeof V1CreateTeacherWorkspaceRequest
>;

/// The identifier the teacher's classes will hang from.
///
/// Returned so the client can hydrate without a second round trip; it is not
/// copy, and no screen renders it.
export const V1CreateTeacherWorkspaceResponse = z.strictObject({
  id: Id,
  name: z.string().min(1).max(160),
  timezone: z.string().min(1).max(64),
  locale: z.string().min(2).max(8),
  role: z.literal("teacher"),
});
export type V1CreateTeacherWorkspaceResponse = z.infer<
  typeof V1CreateTeacherWorkspaceResponse
>;

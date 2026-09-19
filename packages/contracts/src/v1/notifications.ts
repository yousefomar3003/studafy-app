import { z } from "zod";

const Id = z.string().uuid();

export const V1Notification = z.strictObject({
  id: z.string().min(1),
  templateKey: z.string(),
  payload: z.record(z.string(), z.unknown()),
  createdAt: z.string().datetime({ offset: true }),
  readAt: z.string().datetime({ offset: true }).nullable(),
});
export type V1Notification = z.infer<typeof V1Notification>;

export const V1NotificationPage = z.strictObject({
  items: z.array(V1Notification),
  nextCursor: z.string().nullable(),
});
export type V1NotificationPage = z.infer<typeof V1NotificationPage>;

export const V1UnreadCountResponse = z.strictObject({
  unreadCount: z.number().int().min(0),
});
export type V1UnreadCountResponse = z.infer<typeof V1UnreadCountResponse>;

// ids and all are mutually exclusive in practice (private.api042_command's
// markNotificationsRead branches on `all` first); both optional here rather
// than a .refine() so this stays a plain object schema for the OpenAPI/
// additionalProperties generation the same way every other request does.
export const V1MarkNotificationsReadRequest = z.strictObject({
  ids: z.array(z.string().min(1)).max(100).optional(),
  all: z.boolean().optional(),
});
export type V1MarkNotificationsReadRequest = z.infer<
  typeof V1MarkNotificationsReadRequest
>;

export const V1MarkNotificationsReadResponse = z.strictObject({
  markedCount: z.number().int().min(0),
});
export type V1MarkNotificationsReadResponse = z.infer<
  typeof V1MarkNotificationsReadResponse
>;

export const V1NotificationPreference = z.strictObject({
  schoolId: Id.nullable(),
  channel: z.enum(["in_app", "email", "push"]),
  category: z.string(),
  enabled: z.boolean(),
});
export type V1NotificationPreference = z.infer<
  typeof V1NotificationPreference
>;

// Not really paginated (the set is small and bounded), but shaped like
// every other list response - including the always-present nextCursor -
// since the shared catalogue dispatcher adds that field to any response
// carrying "items" regardless of whether the caller ever needs to follow it.
export const V1NotificationPreferencesResponse = z.strictObject({
  items: z.array(V1NotificationPreference),
  nextCursor: z.string().nullable(),
});
export type V1NotificationPreferencesResponse = z.infer<
  typeof V1NotificationPreferencesResponse
>;

export const V1UpdateNotificationPreferenceRequest = z.strictObject({
  schoolId: Id.optional(),
  channel: z.enum(["in_app", "email", "push"]),
  category: z.string().trim().min(1).max(60),
  enabled: z.boolean(),
});
export type V1UpdateNotificationPreferenceRequest = z.infer<
  typeof V1UpdateNotificationPreferenceRequest
>;

/** DL-053: this device's FCM token, for push delivery. */
export const V1RegisterPushDeviceRequest = z.strictObject({
  platform: z.enum(["ios", "android"]),
  token: z.string().min(32).max(4096),
});
export type V1RegisterPushDeviceRequest = z.infer<
  typeof V1RegisterPushDeviceRequest
>;

export const V1UnregisterPushDeviceRequest = z.strictObject({
  token: z.string().min(32).max(4096),
});
export type V1UnregisterPushDeviceRequest = z.infer<
  typeof V1UnregisterPushDeviceRequest
>;

export const V1PushDeviceResponse = z.strictObject({
  registered: z.boolean(),
});
export type V1PushDeviceResponse = z.infer<typeof V1PushDeviceResponse>;

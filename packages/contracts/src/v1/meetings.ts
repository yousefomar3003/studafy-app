import { z } from "zod";

const Id = z.string().uuid();
const Version = z.number().int().positive();

export const V1Meeting = z.strictObject({
  id: Id,
  classroomId: Id,
  title: z.string(),
  startsAt: z.string().datetime({ offset: true }),
  endsAt: z.string().datetime({ offset: true }),
  audience: z.enum(["students", "guardians", "both"]),
  state: z.enum(["pending", "scheduled", "cancelled", "failed"]),
  meetUrl: z.string().url().nullable(),
  version: Version,
  recipientCount: z.number().int().min(0),
});
export type V1Meeting = z.infer<typeof V1Meeting>;

export const V1RequestMeetingRequest = z.strictObject({
  title: z.string().trim().min(1).max(200),
  startsAt: z.string().datetime({ offset: true }),
  endsAt: z.string().datetime({ offset: true }),
  audience: z.enum(["students", "guardians", "both"]).default("both"),
});
export type V1RequestMeetingRequest = z.infer<typeof V1RequestMeetingRequest>;

export const V1CancelMeetingRequest = z.strictObject({
  expectedVersion: Version,
});
export type V1CancelMeetingRequest = z.infer<typeof V1CancelMeetingRequest>;

export const V1MeetingDelivery = z.strictObject({
  recipientId: Id,
  state: z.enum(["queued", "sent", "failed", "cancelled"]),
  deliveredAt: z.string().datetime({ offset: true }).nullable(),
});
export type V1MeetingDelivery = z.infer<typeof V1MeetingDelivery>;

export const V1MeetingStatusResponse = z.strictObject({
  meeting: V1Meeting,
  deliveries: z.array(V1MeetingDelivery),
});
export type V1MeetingStatusResponse = z.infer<typeof V1MeetingStatusResponse>;

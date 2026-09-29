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
  /**
   * The Google Meet link the teacher created. Studafy does not host the call;
   * with a link the meeting is scheduled and its audience notified at once.
   * Only meet.google.com links are accepted - this link goes to every family
   * in the class, so it must not be able to point anywhere else.
   */
  meetUrl: z.string().trim().max(300).regex(
    /^https:\/\/meet\.google\.com\/[A-Za-z0-9-]{3,64}(\?[A-Za-z0-9=&._-]{0,200})?$/,
    "must be a https://meet.google.com/ link",
  ).optional(),
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

/** A meeting as it appears in someone's list: with its class's name. */
export const V1MeetingListItem = V1Meeting.extend({
  classroomName: z.string(),
});
export type V1MeetingListItem = z.infer<typeof V1MeetingListItem>;

/**
 * Upcoming meetings the caller was invited to, and for staff their classes'
 * meetings, soonest first.
 */
export const V1MeetingList = z.strictObject({
  items: z.array(V1MeetingListItem),
  nextCursor: z.string().nullable(),
});
export type V1MeetingList = z.infer<typeof V1MeetingList>;

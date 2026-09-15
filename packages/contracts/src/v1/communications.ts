import { z } from "zod";

const Id = z.string().uuid();

export const V1Conversation = z.strictObject({
  id: Id,
  schoolId: Id,
  subject: z.string().nullable(),
  state: z.enum(["active", "archived", "closed"]),
  lastReadAt: z.string().datetime({ offset: true }).nullable(),
});
export type V1Conversation = z.infer<typeof V1Conversation>;

export const V1ConversationPage = z.strictObject({
  items: z.array(V1Conversation),
  nextCursor: z.string().nullable(),
});
export type V1ConversationPage = z.infer<typeof V1ConversationPage>;

export const V1CreateConversationRequest = z.strictObject({
  schoolId: Id,
  subject: z.string().trim().max(160).optional(),
  participantIds: z.array(Id).min(1).max(50),
});
export type V1CreateConversationRequest = z.infer<
  typeof V1CreateConversationRequest
>;

export const V1Message = z.strictObject({
  id: Id,
  conversationId: Id,
  senderId: Id,
  clientMessageId: Id,
  body: z.string(),
  createdAt: z.string().datetime({ offset: true }),
});
export type V1Message = z.infer<typeof V1Message>;

export const V1MessagePage = z.strictObject({
  items: z.array(V1Message),
  nextCursor: z.string().nullable(),
});
export type V1MessagePage = z.infer<typeof V1MessagePage>;

export const V1SendMessageRequest = z.strictObject({
  clientMessageId: Id,
  body: z.string().trim().min(1).max(4000),
});
export type V1SendMessageRequest = z.infer<typeof V1SendMessageRequest>;

export const V1Announcement = z.strictObject({
  id: Id,
  schoolId: Id,
  classroomId: Id.nullable(),
  title: z.string(),
  body: z.string(),
  audience: z.enum(["students", "guardians", "both"]),
  important: z.boolean(),
  publishedAt: z.string().datetime({ offset: true }),
});
export type V1Announcement = z.infer<typeof V1Announcement>;

export const V1AnnouncementPage = z.strictObject({
  items: z.array(V1Announcement),
  nextCursor: z.string().nullable(),
});
export type V1AnnouncementPage = z.infer<typeof V1AnnouncementPage>;

export const V1CreateAnnouncementRequest = z.strictObject({
  schoolId: Id,
  classroomId: Id.optional(),
  title: z.string().trim().min(1).max(200),
  body: z.string().trim().min(1).max(4000),
  audience: z.enum(["students", "guardians", "both"]).default("both"),
  important: z.boolean().default(false),
});
export type V1CreateAnnouncementRequest = z.infer<
  typeof V1CreateAnnouncementRequest
>;

import { z } from "zod";

const Id = z.string().uuid();

/** Coarse role for display and report targeting; never an authority input. */
export const V1MessagingRole = z.enum(["staff", "student", "guardian"]);
export type V1MessagingRole = z.infer<typeof V1MessagingRole>;

export const V1ConversationParticipant = z.strictObject({
  userId: Id,
  displayName: z.string(),
  role: V1MessagingRole,
});
export type V1ConversationParticipant = z.infer<
  typeof V1ConversationParticipant
>;

export const V1Conversation = z.strictObject({
  id: Id,
  schoolId: Id,
  subject: z.string().nullable(),
  state: z.enum(["active", "archived", "closed"]),
  lastReadAt: z.string().datetime({ offset: true }).nullable(),
  updatedAt: z.string().datetime({ offset: true }),
  participants: z.array(V1ConversationParticipant).max(51),
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

/**
 * People the caller may open a conversation with in one school, after the
 * DL-049 contact policy: staff reach anyone, anyone reaches staff, and a
 * guardian and their verified linked child reach each other.
 */
export const V1Contact = z.strictObject({
  userId: Id,
  displayName: z.string(),
  role: V1MessagingRole,
  /** Populated only for a staff caller looking at a guardian. */
  relatedStudentNames: z.array(z.string()).max(20),
  /**
   * The same children by id. Names alone cannot identify a child: a class
   * can hold two with the same display name.
   */
  relatedStudentIds: z.array(Id).max(20),
});
export type V1Contact = z.infer<typeof V1Contact>;

export const V1ContactPage = z.strictObject({
  items: z.array(V1Contact),
  nextCursor: z.string().nullable(),
});
export type V1ContactPage = z.infer<typeof V1ContactPage>;

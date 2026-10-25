import { z } from "zod";
import { V1QuestionOption } from "./academic";

const Id = z.string().uuid();
const Timestamp = z.string().datetime({ offset: true });

/**
 * AI-suggested marks against the teacher's reference (ADR-0046, DL-073).
 *
 * The teacher writes the reference - per question of an online assessment,
 * or per hand-in of a graded assignment - and may ask for suggestions. A
 * suggestion is a draft for the teacher only: it never becomes a mark until
 * the teacher saves one through the existing marking routes.
 */
export const V1MarkingStrictness = z.enum(["lenient", "balanced", "strict"]);
export type V1MarkingStrictness = z.infer<typeof V1MarkingStrictness>;

/** Something a complete answer must contain, and what it is worth. */
export const V1MarkingKeyPoint = z.strictObject({
  text: z.string().trim().min(1).max(500),
  marks: z.number().nonnegative().max(1000).optional(),
});
export type V1MarkingKeyPoint = z.infer<typeof V1MarkingKeyPoint>;

export const V1MarkingSettings = z.strictObject({
  strictness: V1MarkingStrictness,
  /** Moves on whenever a reference or the strictness changes. */
  referenceVersion: z.number().int().positive(),
});
export type V1MarkingSettings = z.infer<typeof V1MarkingSettings>;

/** One question's reference (or, for a hand-in, the whole piece of work). */
export const V1MarkingReference = z.strictObject({
  /** Null for the hand-in of a graded assignment. */
  questionId: Id.nullable(),
  position: z.number().int().positive(),
  kind: z.enum([
    "single_choice",
    "multiple_choice",
    "true_false",
    "short_answer",
    "essay",
    "hand_in",
  ]).nullable(),
  prompt: z.string().nullable(),
  maximumScore: z.number().positive(),
  options: z.array(V1QuestionOption).max(10),
  /** The keys that mark it automatically, in the field its kind uses. */
  correctOptionIds: z.array(z.string()).nullable(),
  correctChoice: z.boolean().nullable(),
  acceptedAnswers: z.array(z.string()).nullable(),
  /** The model answer or worked solution. */
  preferredAnswer: z.string().nullable(),
  markingGuidance: z.string().nullable(),
  keyPoints: z.array(V1MarkingKeyPoint).max(20),
  /** Other answers or methods that earn credit. */
  acceptedMethods: z.string().nullable(),
  /** How part marks are given. */
  partialCredit: z.string().nullable(),
});
export type V1MarkingReference = z.infer<typeof V1MarkingReference>;

export const V1MarkingReferences = z.strictObject({
  delivery: z.string(),
  settings: V1MarkingSettings,
  references: z.array(V1MarkingReference).max(200),
});
export type V1MarkingReferences = z.infer<typeof V1MarkingReferences>;

export const V1MarkingReferenceUpdate = z.strictObject({
  /** Required for an online assessment's question; absent for a hand-in. */
  questionId: Id.nullable().optional(),
  preferredAnswer: z.string().max(30_000).nullable().optional(),
  markingGuidance: z.string().max(10_000).nullable().optional(),
  keyPoints: z.array(V1MarkingKeyPoint).max(20).optional(),
  acceptedMethods: z.string().max(5_000).nullable().optional(),
  partialCredit: z.string().max(5_000).nullable().optional(),
});
export type V1MarkingReferenceUpdate = z.infer<typeof V1MarkingReferenceUpdate>;

export const V1UpdateMarkingReferencesRequest = z.strictObject({
  strictness: V1MarkingStrictness.optional(),
  references: z.array(V1MarkingReferenceUpdate).max(100).optional(),
});
export type V1UpdateMarkingReferencesRequest = z.infer<
  typeof V1UpdateMarkingReferencesRequest
>;

export const V1UpdateMarkingReferencesResponse = z.strictObject({
  settings: V1MarkingSettings,
  references: z.array(V1MarkingReference).max(200),
  changed: z.boolean(),
  /** Suggestions made against an older reference. Nothing is re-marked by
   * itself: the teacher decides whether to ask again. */
  staleSuggestions: z.number().int().nonnegative(),
});
export type V1UpdateMarkingReferencesResponse = z.infer<
  typeof V1UpdateMarkingReferencesResponse
>;

export const V1MarkingSuggestion = z.strictObject({
  id: Id,
  studentId: Id,
  attemptId: Id.nullable(),
  questionId: Id.nullable(),
  submissionAttemptId: Id.nullable(),
  status: z.enum(["pending", "ready", "failed", "skipped"]),
  maximumScore: z.number().positive(),
  suggestedScore: z.number().nonnegative().nullable(),
  /** The requirements the answer met, and those it missed. */
  met: z.array(z.string().max(500)).max(40),
  missed: z.array(z.string().max(500)).max(40),
  rationale: z.string().max(4000).nullable(),
  /** For the student, to be edited by the teacher before it is used. */
  feedback: z.string().max(2000).nullable(),
  /** The reference disagrees with the question or rubric. */
  conflict: z.string().max(1000).nullable(),
  reviewReason: z.enum([
    "ambiguous",
    "unreadable",
    "no_reference",
    "conflict",
    "empty",
  ]).nullable(),
  /** Why it was skipped or failed: opted_out, unreadable, ... */
  reason: z.string().max(60).nullable(),
  referenceVersion: z.number().int().positive(),
  strictness: V1MarkingStrictness,
  /** Made against an older reference than the current one. */
  stale: z.boolean(),
  createdAt: Timestamp,
  updatedAt: Timestamp,
});
export type V1MarkingSuggestion = z.infer<typeof V1MarkingSuggestion>;

export const V1MarkingSuggestionList = z.strictObject({
  settings: V1MarkingSettings,
  items: z.array(V1MarkingSuggestion).max(5000),
});
export type V1MarkingSuggestionList = z.infer<typeof V1MarkingSuggestionList>;

export const V1RequestMarkingSuggestionsRequest = z.strictObject({
  /** "unmarked" (default): work with no mark yet. "all": every written
   * answer or hand-in, replacing earlier suggestions. */
  scope: z.enum(["unmarked", "all"]).optional(),
  studentIds: z.array(Id).min(1).max(500).optional(),
});
export type V1RequestMarkingSuggestionsRequest = z.infer<
  typeof V1RequestMarkingSuggestionsRequest
>;

export const V1MarkingRun = z.strictObject({
  runId: Id,
  referenceVersion: z.number().int().positive(),
  strictness: V1MarkingStrictness,
  queued: z.number().int().nonnegative(),
  /** Students who opted out: marked by hand. */
  optedOut: z.number().int().nonnegative(),
  /** Earlier suggestions this run replaces. */
  replaced: z.number().int().nonnegative(),
});
export type V1MarkingRun = z.infer<typeof V1MarkingRun>;

export const V1DismissMarkingSuggestionRequest = z.strictObject({});
export type V1DismissMarkingSuggestionRequest = z.infer<
  typeof V1DismissMarkingSuggestionRequest
>;
export const V1DismissMarkingSuggestionResponse = z.strictObject({
  id: Id,
  status: z.literal("dismissed"),
});
export type V1DismissMarkingSuggestionResponse = z.infer<
  typeof V1DismissMarkingSuggestionResponse
>;

/** The caller's Studafy AI Marking plan and this month's allowance. */
export const V1MarkingPlan = z.strictObject({
  active: z.boolean(),
  teacher: z.boolean(),
  /** The server can make suggestions at all (an AI provider, switched on). */
  available: z.boolean(),
  allowance: z.strictObject({
    total: z.number().int().nonnegative(),
    used: z.number().int().nonnegative(),
    resetsAt: Timestamp,
  }),
});
export type V1MarkingPlan = z.infer<typeof V1MarkingPlan>;

/** A student's choice: their work is never sent to the AI. */
export const V1MarkingPreference = z.strictObject({ optedOut: z.boolean() });
export type V1MarkingPreference = z.infer<typeof V1MarkingPreference>;
export const V1UpdateMarkingPreferenceRequest = z.strictObject({
  optedOut: z.boolean(),
});
export type V1UpdateMarkingPreferenceRequest = z.infer<
  typeof V1UpdateMarkingPreferenceRequest
>;

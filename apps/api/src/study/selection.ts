import {
  type ResolvedScope,
  type SelectionResult,
  sha256Hex,
} from "@studafy/infrastructure";
import type { Context } from "hono";
import { problem } from "../platform/errors";

/**
 * Exactly the material a student chose (2026-10-07, ADR-0039).
 *
 * Every AI study tool takes a list of references - whole lessons, a
 * lesson's own text, single files and links, and for the helper the
 * student's own notes. They are resolved here against what the student
 * can see on this request, and nothing else is ever read:
 *
 * - a lesson they cannot see refuses the request (`not_found`), it is not
 *   quietly dropped;
 * - a file or link must belong to the lesson it names;
 * - a chosen file that cannot be read now refuses the request with its
 *   name (`material_unavailable`), unless the student chose to go on
 *   without it - then it is left out and said so;
 * - an empty choice of files never means "all of them".
 */

// Resolving and gathering are shared with the worker's notebook writer
// (2026-10-16); the API adds how a refusal is answered and what a result
// records.
export {
  gatherScope,
  type MaterialRef,
  MAX_SELECTED_LESSONS,
  type ResolvedLesson,
  type ResolvedScope,
  resolveSelection,
  type SelectionResult,
  type SkippedSource,
} from "@studafy/infrastructure";

/** The refusal for a selection that could not be used. */
export function selectionProblem(
  c: Context,
  result: Exclude<SelectionResult, { ok: true }>,
): Response {
  switch (result.outcome) {
    case "not_found":
      return problem(c, "NOT_FOUND", 404);
    case "invalid":
      return problem(c, "INVALID_REQUEST", 400);
    case "no_material":
      return problem(c, "LESSON_HAS_NO_TEXT", 422);
    case "material_unavailable":
      return problem(c, "MATERIAL_UNAVAILABLE", 409, {
        errors: result.unavailable.map((s) => ({
          path: `sources/${s.id}`,
          code: s.state === "processing" ? "processing" : s.reason ?? s.state,
        })),
      });
  }
}

/** What a result was made from, as the contract describes it. */
export function scopeJson(scope: ResolvedScope) {
  return {
    lessons: scope.lessons.map((l) => ({
      resourceId: l.resourceId,
      classroomId: l.classroomId,
      title: l.title.slice(0, 300),
      includeText: l.includeText,
      wholeLesson: l.wholeLesson,
      sources: l.kept.slice(0, 40).map((s) => ({
        id: s.id,
        kind: s.kind === "link" ? "link" as const : "file" as const,
        name: s.name.slice(0, 300),
      })),
    })),
    skipped: scope.skipped.slice(0, 40).map((s) => ({
      id: s.id,
      name: s.name.slice(0, 300),
      reason: (s.state === "processing" ? "processing" : s.reason ?? s.state)
        .slice(0, 60),
    })),
  };
}

/**
 * The same selection of the same lesson versions gives the same key: the
 * lessons, whether each one's text is in, and the files read.
 */
export async function scopeFingerprint(scope: ResolvedScope): Promise<string> {
  const parts = [...scope.lessons]
    .sort((a, b) => a.resourceId.localeCompare(b.resourceId))
    .map((l) => [
      l.versionId,
      l.includeText ? 1 : 0,
      l.kept.map((s) => s.id).sort(),
    ]);
  return await sha256Hex(new TextEncoder().encode(JSON.stringify(parts)));
}

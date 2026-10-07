import {
  type MaterialPassage,
  namedLocations,
  wantsWholeMaterial,
} from "@studafy/domain";
import { sha256Hex } from "@studafy/infrastructure";
import type { Context } from "hono";
import type { RequestDbContext } from "../platform/dbContext";
import { problem } from "../platform/errors";
import {
  type GatheredMaterial,
  type MaterialRepository,
  type UnreadableEntry,
  unreadableReason,
} from "./material";

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

export interface MaterialRef {
  kind: "lesson" | "text" | "file" | "link" | "note";
  id: string;
  lessonId?: string;
}

interface SourceRow {
  id: string;
  kind: "file" | "link";
  name: string;
  state: string;
  reason: string | null;
}

interface LessonRow {
  resourceId: string;
  versionId: string;
  classroomId: string;
  grade: string | null;
  title: string;
  body: string;
  sources: SourceRow[];
}

export interface ResolvedLesson extends LessonRow {
  includeText: boolean;
  /** Every file and link on the lesson, all of them readable. */
  wholeLesson: boolean;
  /** The chosen files and links that will be read. */
  kept: SourceRow[];
}

export interface SkippedSource {
  id: string;
  name: string;
  state: string;
  reason: string | null;
}

export interface ResolvedScope {
  lessons: ResolvedLesson[];
  /** Chosen but left out: the student went on without them. */
  skipped: SkippedSource[];
  /** The student's own notes, for the helper. */
  noteIds: string[];
}

export type SelectionResult =
  | { ok: true; scope: ResolvedScope }
  | { ok: false; outcome: "not_found" | "invalid" | "no_material" }
  | {
    ok: false;
    outcome: "material_unavailable";
    unavailable: SkippedSource[];
  };

export const MAX_SELECTED_LESSONS = 10;

export async function resolveSelection(
  repository: MaterialRepository,
  context: RequestDbContext,
  refs: MaterialRef[],
  options: { skipUnavailable?: boolean; allowNotes?: boolean } = {},
): Promise<SelectionResult> {
  const noteIds = refs.filter((r) => r.kind === "note").map((r) => r.id);
  if (noteIds.length > 0 && !options.allowNotes) {
    return { ok: false, outcome: "invalid" };
  }
  const byLesson = new Map<string, MaterialRef[]>();
  for (const ref of refs) {
    if (ref.kind === "note") continue;
    const lessonId = ref.kind === "lesson" || ref.kind === "text"
      ? ref.id
      : ref.lessonId;
    if (!lessonId) return { ok: false, outcome: "invalid" };
    byLesson.set(lessonId, [...(byLesson.get(lessonId) ?? []), ref]);
  }
  if (byLesson.size > MAX_SELECTED_LESSONS) {
    return { ok: false, outcome: "invalid" };
  }
  if (byLesson.size === 0) {
    return noteIds.length > 0
      ? { ok: true, scope: { lessons: [], skipped: [], noteIds } }
      : { ok: false, outcome: "invalid" };
  }

  const found = await repository.call(context, "lessons", {
    resourceIds: [...byLesson.keys()],
  });
  const rows = new Map(
    ((found["lessons"] ?? []) as LessonRow[]).map((l) => [l.resourceId, l]),
  );

  const lessons: ResolvedLesson[] = [];
  const unavailable: SkippedSource[] = [];
  for (const [lessonId, lessonRefs] of byLesson) {
    const row = rows.get(lessonId);
    // Not visible to this student now: refused, never skipped.
    if (!row) return { ok: false, outcome: "not_found" };
    const whole = lessonRefs.some((r) => r.kind === "lesson");
    const includeText = whole || lessonRefs.some((r) => r.kind === "text");
    const sources = new Map(row.sources.map((s) => [s.id, s]));
    let chosen: SourceRow[];
    if (whole) {
      chosen = row.sources;
    } else {
      chosen = [];
      for (const ref of lessonRefs) {
        if (ref.kind !== "file" && ref.kind !== "link") continue;
        const source = sources.get(ref.id);
        // Not on this lesson: a request for something else entirely.
        if (!source) return { ok: false, outcome: "invalid" };
        if (!chosen.includes(source)) chosen.push(source);
      }
    }
    const missing = chosen.filter((s) => s.state !== "ready");
    unavailable.push(
      ...missing.map((s) => ({
        id: s.id,
        name: s.name,
        state: s.state,
        reason: s.reason,
      })),
    );
    lessons.push({
      ...row,
      includeText,
      wholeLesson: whole && missing.length === 0,
      kept: chosen.filter((s) => s.state === "ready"),
    });
  }

  if (unavailable.length > 0 && !options.skipUnavailable) {
    return { ok: false, outcome: "material_unavailable", unavailable };
  }
  const anything = lessons.some((l) =>
    l.kept.length > 0 || (l.includeText && l.body.trim().length > 0)
  );
  if (!anything && noteIds.length === 0) {
    return { ok: false, outcome: "no_material" };
  }
  return { ok: true, scope: { lessons, skipped: unavailable, noteIds } };
}

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

/**
 * The passages for a resolved selection: each lesson's text where it was
 * chosen, then passages from the chosen files and links only.
 */
export async function gatherScope(
  repository: MaterialRepository,
  context: RequestDbContext,
  scope: ResolvedScope,
  request: {
    question: string;
    followUp?: string;
    budgetChars: number;
    mode?: "auto" | "coverage";
  },
): Promise<GatheredMaterial> {
  const passages: MaterialPassage[] = [];
  let budget = request.budgetChars;
  const kept = scope.lessons.flatMap((l) => l.kept.map((s) => s.id));
  const texts = scope.lessons.filter((l) =>
    l.includeText && l.body.trim().length > 0
  );
  // The lessons' own text: a third of the budget when there are files to
  // read too, all of it when there are none.
  const textShare = texts.length === 0 ? 0 : Math.floor(
    (kept.length > 0 ? request.budgetChars / 3 : request.budgetChars) /
      texts.length,
  );
  for (const lesson of texts) {
    const text = lesson.body.trim().slice(0, textShare);
    passages.push({ sourceKind: "lesson", name: lesson.title, text });
    budget -= text.length;
  }

  if (kept.length > 0) {
    const { pages, slides } = namedLocations(request.question);
    const mode =
      request.mode === "coverage" || wantsWholeMaterial(request.question)
        ? "coverage"
        : "search";
    const reading = scope.lessons.filter((l) => l.kept.length > 0);
    const retrieved = await repository.call(context, "retrieve", {
      resourceIds: reading.map((l) => l.resourceId),
      // Never empty here: an empty list would mean every file.
      sourceIds: kept,
      query: [request.question, request.followUp ?? ""].join(" ").slice(
        0,
        2_000,
      ),
      pages,
      slides,
      mode,
      budgetChars: Math.max(500, budget),
    });
    const single = scope.lessons.length === 1 ? scope.lessons[0]!.title : null;
    for (
      const p of (retrieved["passages"] ?? []) as Record<string, unknown>[]
    ) {
      passages.push({
        sourceKind: p["sourceKind"] === "link" ? "link" : "file",
        name: String(p["name"] ?? "file"),
        lessonTitle: single,
        page: typeof p["page"] === "number" ? p["page"] : null,
        slide: typeof p["slide"] === "number" ? p["slide"] : null,
        heading: typeof p["heading"] === "string" ? p["heading"] : null,
        text: String(p["text"] ?? ""),
      });
    }
  }

  const unreadable: UnreadableEntry[] = scope.skipped.map((s) => ({
    name: s.name,
    reason: unreadableReason(s.state, s.reason),
    code: s.state === "processing" ? "processing" : s.reason ?? s.state,
  }));
  const grades = new Set(scope.lessons.map((l) => l.grade));
  return {
    passages,
    unreadable,
    grade: grades.size === 1 ? [...grades][0] ?? null : null,
    lessonCount: scope.lessons.length,
    pending: false,
    chars: passages.reduce((n, p) => n + p.text.length, 0),
  };
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

import {
  type MaterialPassage,
  namedLocations,
  type UnreadableSource,
  wantsWholeMaterial,
} from "@studafy/domain";
import type { StudyCallContext } from "./metering";

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
 *
 * Shared by the API and the worker's notebook writer (2026-10-16).
 */

/**
 * Class material for the AI (ADR-0037): `private.api054_ai_material` run as
 * the student, which decides on each call which lessons they can see now.
 */
export interface StudyMaterialSource {
  call(
    context: StudyCallContext,
    operation: "lessons" | "retrieve",
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
}

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

/** Why a source could not be used, in words the model passes on. */
export function unreadableReason(state: string, reason: string | null): string {
  if (state === "processing") return "still being read - try again shortly";
  switch (reason) {
    case "needs_model":
    case "reading_budget_used":
      return "its scanned pages were not read";
    case "no_text":
      return "it has no readable text";
    case "unsupported_type":
      return "this kind of file cannot be read";
    case "link_needs_sign_in":
      return "the link needs a sign-in";
    case "link_video":
      return "it is a video";
    case "link_not_found":
      return "the link no longer exists";
    case "link_blocked_address":
    case "link_unreachable":
    case "link_unsupported_type":
    case "link_too_large":
      return "the link could not be opened";
    default:
      return "it could not be read";
  }
}

/** A source that could not be used: words for the model, a code for the app. */
export interface UnreadableEntry extends UnreadableSource {
  code: string;
}

export interface GatheredMaterial {
  passages: MaterialPassage[];
  unreadable: UnreadableEntry[];
  /** The class's grade, when exactly one class is involved. */
  grade: string | null;
  /** Lessons the student could see, of those asked for. */
  lessonCount: number;
  /** A chosen file or link is still being read. */
  pending: boolean;
  chars: number;
}

export async function resolveSelection(
  repository: StudyMaterialSource,
  context: StudyCallContext,
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

/**
 * The passages for a resolved selection: each lesson's text where it was
 * chosen, then passages from the chosen files and links only.
 */
export async function gatherScope(
  repository: StudyMaterialSource,
  context: StudyCallContext,
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

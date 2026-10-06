import type { Sql } from "@studafy/database";
import {
  type MaterialPassage,
  namedLocations,
  type UnreadableSource,
  wantsWholeMaterial,
} from "@studafy/domain";
import {
  type RequestDbContext,
  withRequestContext,
} from "../platform/dbContext";

/**
 * Class material for the AI (ADR-0037). Every read runs as the requesting
 * user through `private.api054_ai_material`, which decides on each request
 * which lessons they can see now - the API never chooses that.
 */
export interface MaterialRepository {
  call(
    context: RequestDbContext,
    operation: "lessons" | "retrieve" | "status" | "retry" | "pending",
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>>;
}

export class PostgresMaterialRepository implements MaterialRepository {
  constructor(readonly sql: Sql) {}

  async call(
    context: RequestDbContext,
    operation: string,
    input: Record<string, unknown>,
  ): Promise<Record<string, unknown>> {
    return await withRequestContext(this.sql, context, async (tx) => {
      const rows = await tx<{ result: Record<string, unknown> }[]>`
        select private.api054_ai_material(${operation}, ${
        tx.json(input as never)
      }) as result
      `;
      return rows[0]?.result ?? { outcome: "invalid" };
    });
  }
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
  title: string;
  body: string;
  grade: string | null;
  sources: SourceRow[];
}

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

/**
 * The material for one request: the lessons' own text, then the passages
 * that best fit the question - or, for a summary or a quiz, passages spread
 * across all of it - within [budgetChars].
 */
export async function gatherMaterial(
  repository: MaterialRepository,
  context: RequestDbContext,
  request: {
    lessonIds: string[];
    /** Files or links chosen on their own; empty for whole lessons. */
    sourceIds: string[];
    question: string;
    /** The previous question, so "explain more" still finds its topic. */
    followUp?: string;
    budgetChars: number;
    mode?: "auto" | "coverage";
  },
): Promise<GatheredMaterial> {
  const empty: GatheredMaterial = {
    passages: [],
    unreadable: [],
    grade: null,
    lessonCount: 0,
    pending: false,
    chars: 0,
  };
  if (request.lessonIds.length === 0) return empty;
  const found = await repository.call(context, "lessons", {
    resourceIds: request.lessonIds,
  });
  const lessons = (found["lessons"] ?? []) as LessonRow[];
  if (lessons.length === 0) return empty;
  const chosen = new Set(request.sourceIds);
  const passages: MaterialPassage[] = [];
  const unreadable: UnreadableEntry[] = [];
  let pending = false;
  let budget = request.budgetChars;

  for (const lesson of lessons) {
    for (const source of lesson.sources) {
      if (chosen.size > 0 && !chosen.has(source.id)) continue;
      if (source.state === "ready") continue;
      if (source.state === "processing") pending = true;
      unreadable.push({
        name: source.name,
        reason: unreadableReason(source.state, source.reason),
        code: source.state === "processing"
          ? "processing"
          : source.reason ?? source.state,
      });
    }
  }

  // The lesson's own text, unless the student chose particular files: at
  // most a third of the budget, shared between the lessons.
  const lessonsChosenWhole = chosen.size === 0 ||
    lessons.every((l) => !l.sources.some((s) => chosen.has(s.id)));
  if (lessonsChosenWhole) {
    const share = Math.floor(request.budgetChars / 3 / lessons.length);
    for (const lesson of lessons) {
      const text = lesson.body.trim();
      if (!text) continue;
      const kept = text.slice(0, share);
      passages.push({
        sourceKind: "lesson",
        name: lesson.title,
        text: kept,
      });
      budget -= kept.length;
    }
  }

  const { pages, slides } = namedLocations(request.question);
  const mode =
    request.mode === "coverage" || wantsWholeMaterial(request.question)
      ? "coverage"
      : "search";
  const retrieved = await repository.call(context, "retrieve", {
    resourceIds: lessons.map((l) => l.resourceId),
    sourceIds: [...chosen],
    query: [request.question, request.followUp ?? ""].join(" ").slice(0, 2_000),
    pages,
    slides,
    mode,
    budgetChars: Math.max(500, budget),
  });
  const single = lessons.length === 1 ? lessons[0]!.title : null;
  for (const p of (retrieved["passages"] ?? []) as Record<string, unknown>[]) {
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
  const grades = new Set(lessons.map((l) => l.grade).filter(Boolean));
  return {
    passages,
    unreadable,
    grade: grades.size === 1 ? [...grades][0]! : null,
    lessonCount: lessons.length,
    pending,
    chars: passages.reduce((n, p) => n + p.text.length, 0),
  };
}

/** Material as one text, labelled by source, for notes and study sets. */
export function materialText(passages: MaterialPassage[]): string {
  return passages.map((p) => {
    const where = p.page
      ? ` (p. ${p.page})`
      : p.slide
      ? ` (slide ${p.slide})`
      : "";
    return `### ${p.name}${where}${
      p.heading ? ` - ${p.heading}` : ""
    }\n${p.text}`;
  }).join("\n\n");
}

import type { NotebookContent } from "@studafy/domain";
import { type StudyAssistant, StudyAssistantError } from "../studyAssistant";
import {
  AiMeter,
  type AiUsageLedger,
  holdFor,
  type ModelPrices,
  type StudyCallContext,
} from "./metering";
import {
  gatherScope,
  type MaterialRef,
  resolveSelection,
  type StudyMaterialSource,
} from "./selection";

/**
 * Writing a study notebook's AI part (ADR-0038).
 *
 * Since 2026-10-16 this runs on the worker's notebook queue, not in the API
 * process: the API records the notebook and its job in one transaction and
 * answers "creating"; the worker claims the job, writes it here as the
 * notebook's owner, and reports what happened. The app polls as before.
 */

/** The longest a notebook's AI reply may be. */
export const NOTEBOOK_OUTPUT_TOKENS = 3_500;

/** The class material read for a quiz, flashcards, notes or a notebook. */
export const STUDY_SET_MATERIAL_CHARS = 40_000;

/** What a notebook is made from, as `private.notebook_start_json` gives it. */
export interface NotebookStart {
  notebookId: string;
  generation: number;
  resourceId: string;
  lessonTitle?: string | null;
  sourceIds?: string[];
  includeText?: boolean;
  wholeLesson?: boolean;
}

/**
 * - `ready`: the notebook, to be saved;
 * - `failed`: a reason the student sees, with a retry - trying again
 *   without them would fail the same way or charge twice;
 * - `retry`: nothing was charged and it may work later (the provider was
 *   busy, the database briefly unreachable).
 */
export type NotebookWriteResult =
  | {
    outcome: "ready";
    content: NotebookContent;
    unreadable: { name: string; reason: string }[];
    model: string;
  }
  | { outcome: "failed"; reason: string }
  | { outcome: "retry"; reason: string };

export interface NotebookWriterDeps {
  material: StudyMaterialSource;
  usage: AiUsageLedger;
  prices: ModelPrices;
  /** Null without an AI provider. */
  assistant: Pick<StudyAssistant, "notebook"> | null;
  logger?: { warn(event: string, fields?: Record<string, unknown>): void };
}

/** A notebook's material as references: the whole lesson, or its text
 * (when kept) and the chosen files and links. */
export function notebookRefs(
  resourceId: string,
  sourceIds: string[],
  includeText: boolean,
  wholeLesson: boolean,
): MaterialRef[] {
  if (wholeLesson) return [{ kind: "lesson", id: resourceId }];
  return [
    ...(includeText ? [{ kind: "text" as const, id: resourceId }] : []),
    ...sourceIds.map((id) => ({
      kind: "file" as const,
      id,
      lessonId: resourceId,
    })),
  ];
}

/** The ledger key of one generation: every attempt at it shares it, so it
 * is charged once. */
export function notebookRequestKey(id: string, generation: number): string {
  return `notebook:${id}:${generation}`;
}

/**
 * Gathers the chosen material as the owner sees it now, asks the model, and
 * says what came of it. Never throws.
 */
export async function writeNotebook(
  deps: NotebookWriterDeps,
  context: StudyCallContext,
  started: NotebookStart,
): Promise<NotebookWriteResult> {
  const id = String(started.notebookId);
  const generation = Number(started.generation);
  const assistant = deps.assistant;
  if (!assistant) return { outcome: "failed", reason: "provider_unavailable" };
  try {
    // Exactly what the notebook was made from. A file that can no longer
    // be read is left out and listed in the notebook, with a retry.
    const selection = await resolveSelection(
      deps.material,
      context,
      notebookRefs(
        String(started.resourceId),
        started.sourceIds ?? [],
        started.includeText !== false,
        started.wholeLesson !== false,
      ),
      { skipUnavailable: true },
    );
    if (!selection.ok) {
      return {
        outcome: "failed",
        reason: selection.outcome === "not_found"
          ? "lesson_unavailable"
          : "no_readable_material",
      };
    }
    const gathered = await gatherScope(
      deps.material,
      context,
      selection.scope,
      { question: "", budgetChars: STUDY_SET_MATERIAL_CHARS, mode: "coverage" },
    );
    const readable = gathered.passages.filter((p) => p.text.trim());
    if (readable.reduce((n, p) => n + p.text.length, 0) < 40) {
      return { outcome: "failed", reason: "no_readable_material" };
    }
    const metered = await new AiMeter(deps.usage, deps.prices).run(
      context,
      "notes",
      holdFor(deps.prices, gathered.chars, NOTEBOOK_OUTPUT_TOKENS),
      () =>
        assistant.notebook(String(started.lessonTitle ?? ""), readable, {
          unreadable: gathered.unreadable,
          learner: gathered.grade ? { grade: gathered.grade } : {},
        }),
      notebookRequestKey(id, generation),
    );
    if (!metered.ok) {
      // An earlier attempt's hold is still live: try once it has lapsed.
      return metered.outcome === "in_progress"
        ? { outcome: "retry", reason: "usage_in_progress" }
        : { outcome: "failed", reason: metered.outcome };
    }
    return {
      outcome: "ready",
      content: metered.value.content,
      unreadable: gathered.unreadable.slice(0, 100).map((u) => ({
        name: u.name.slice(0, 300),
        reason: u.code.slice(0, 60),
      })),
      model: metered.value.usage?.model ?? "unknown",
    };
  } catch (error) {
    // Neither the material nor the reply is logged: one is a school's,
    // the other a third party's words about it.
    deps.logger?.warn("study_notebook_failed", {
      error_kind: error instanceof StudyAssistantError ? error.kind : "unknown",
      provider_status: error instanceof StudyAssistantError
        ? error.status ?? null
        : null,
    });
    if (!(error instanceof StudyAssistantError)) {
      // The database or the network on our side: nothing was settled.
      return { outcome: "retry", reason: "generation_failed" };
    }
    if (error.kind === "empty") {
      return { outcome: "failed", reason: "unusable_reply" };
    }
    // The provider answered busy or with a server fault: the hold was
    // released, so another attempt costs nothing extra. A request that may
    // have been billed (sent, then timed out) was charged, and is not tried
    // again; neither is one refused outright.
    return error.kind === "unavailable" && !error.billed
      ? { outcome: "retry", reason: "provider_unavailable" }
      : { outcome: "failed", reason: "provider_unavailable" };
  }
}

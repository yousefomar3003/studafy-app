import { type KnownName, type NameKind, nameRedactor } from "@studafy/domain";
import { type StudyAssistant, withNameRedaction } from "../studyAssistant";

/**
 * The names kept out of what is sent to the AI provider (ADR-0043, DPIA D1),
 * as the database lists them for the person an AI call is for.
 *
 * Shared by the API (`private.api057_ai_consent('names')`) and the worker,
 * which writes study notebooks (`private.notebook_job_names`), so both read
 * the same list and replace names the same way before any model call.
 */

/** Why no list of names was read: the call must not be made. */
export class KnownNamesUnavailable extends Error {
  constructor() {
    super("ai_names_unavailable");
    this.name = "KnownNamesUnavailable";
  }
}

const KINDS = new Set<NameKind>(["self", "parent", "teacher", "classmate"]);

/**
 * The names in the database's answer (`{ outcome: "ok", names: [...] }`).
 * Anything else throws [KnownNamesUnavailable]: better no call than one
 * that might carry a name.
 */
export function knownNamesOf(result: Record<string, unknown>): KnownName[] {
  if (result["outcome"] !== "ok" || !Array.isArray(result["names"])) {
    throw new KnownNamesUnavailable();
  }
  return (result["names"] as unknown[]).flatMap((entry) => {
    const row = (entry ?? {}) as Record<string, unknown>;
    const kind = String(row["kind"]) as NameKind;
    const name = typeof row["name"] === "string" ? row["name"] : "";
    return KINDS.has(kind) && name ? [{ name, kind }] : [];
  });
}

/** [assistant] with [names] replaced in everything it sends. */
export function redactingNames<A extends Partial<StudyAssistant>>(
  assistant: A,
  names: readonly KnownName[],
): A {
  const redactor = nameRedactor(names);
  return withNameRedaction(assistant, (text) => redactor.redact(text));
}

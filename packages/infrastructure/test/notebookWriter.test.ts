import { describe, expect, test } from "bun:test";
import type { NotebookContent } from "@studafy/domain";
import {
  AI_ACCESS_FAILURES,
  notebookRequestKey,
  type NotebookWriterDeps,
  StudyAssistantError,
  writeNotebook,
} from "../src/index";

// The notebook writer the worker runs (2026-10-16): what each way a write
// can end becomes - saved, failed with a reason, or tried again - and that
// the ledger is held, settled or released exactly as for any AI call. The
// SQL behind it is apps/worker/test/notebookGeneration.integration.test.ts.

const CONTENT = {
  overview: "Leaves.",
  sections: [],
} as unknown as NotebookContent;
const CONTEXT = {
  subject: "student",
  schoolId: "school",
  requestId: "r",
  aal2: false,
};
const START = {
  notebookId: "nb-1",
  generation: 3,
  resourceId: "lesson-1",
  lessonTitle: "Photosynthesis",
  sourceIds: [],
  includeText: true,
  wholeLesson: true,
};
const LESSON = {
  resourceId: "lesson-1",
  versionId: "v1",
  classroomId: "c1",
  grade: "8",
  title: "Photosynthesis",
  body: "Photosynthesis turns light into chemical energy in chloroplasts.",
  sources: [],
};

function deps(
  notebook: (...args: never[]) => Promise<unknown>,
  options: {
    lessons?: unknown[];
    reserve?: string;
    names?: () => Promise<Record<string, unknown>>;
  } = {},
) {
  const ledger: { operation: string; input: Record<string, unknown> }[] = [];
  const d: NotebookWriterDeps = {
    names: {
      names: options.names ?? (async () => ({ outcome: "ok", names: [] })),
    },
    material: {
      call: async (_c, operation) =>
        operation === "lessons"
          ? { outcome: "ok", lessons: options.lessons ?? [LESSON] }
          : { outcome: "ok", passages: [] },
    },
    usage: {
      usage: async (_c, operation, input) => {
        ledger.push({ operation, input });
        if (operation === "reserve" && options.reserve) {
          return { outcome: options.reserve };
        }
        return { outcome: "ok", usageId: "u1" };
      },
    },
    prices: { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 },
    assistant: { notebook: notebook as never },
  };
  return { d, ledger };
}

describe("writeNotebook", () => {
  test("a written notebook is settled under the generation's key", async () => {
    const { d, ledger } = deps(async () => ({
      content: CONTENT,
      usage: { inputTokens: 900, outputTokens: 700, model: "m" },
    }));
    const result = await writeNotebook(d, CONTEXT, START);
    expect(result).toMatchObject({
      outcome: "ready",
      content: CONTENT,
      model: "m",
    });
    expect(ledger.map((l) => l.operation)).toEqual(["reserve", "settle"]);
    expect(ledger[0]!.input).toMatchObject({
      feature: "notes",
      requestKey: notebookRequestKey("nb-1", 3),
    });
    expect(notebookRequestKey("nb-1", 3)).toBe("notebook:nb-1:3");
  });

  test("a busy provider is tried again; its hold is released", async () => {
    const { d, ledger } = deps(async () => {
      throw new StudyAssistantError("unavailable", 503);
    });
    expect(await writeNotebook(d, CONTEXT, START)).toEqual({
      outcome: "retry",
      reason: "provider_unavailable",
    });
    expect(ledger.map((l) => l.operation)).toEqual(["reserve", "release"]);
  });

  test("a request that may have been billed is charged and not tried again", async () => {
    const { d, ledger } = deps(async () => {
      throw new StudyAssistantError("unavailable", undefined, undefined, true);
    });
    expect(await writeNotebook(d, CONTEXT, START)).toEqual({
      outcome: "failed",
      reason: "provider_unavailable",
    });
    expect(ledger.map((l) => l.operation)).toEqual(["reserve", "settle"]);
  });

  test("an unusable reply fails, charged for what it used", async () => {
    const usage = { inputTokens: 10, outputTokens: 20, model: "m" };
    const { d, ledger } = deps(async () => {
      throw new StudyAssistantError("empty", undefined, usage, true);
    });
    expect(await writeNotebook(d, CONTEXT, START)).toEqual({
      outcome: "failed",
      reason: "unusable_reply",
    });
    expect(ledger.map((l) => l.operation)).toEqual(["reserve", "settle"]);
    expect(ledger[1]!.input).toMatchObject({
      inputTokens: 10,
      outputTokens: 20,
    });
  });

  test("a refused provider fails without being tried again", async () => {
    const { d } = deps(async () => {
      throw new StudyAssistantError("refused");
    });
    expect(await writeNotebook(d, CONTEXT, START)).toEqual({
      outcome: "failed",
      reason: "provider_unavailable",
    });
  });

  test("our own trouble (the database) is tried again, charging nothing", async () => {
    const { d } = deps(async () => ({ content: CONTENT }));
    d.material = {
      call: () => Promise.reject(new Error("connection reset")),
    };
    expect(await writeNotebook(d, CONTEXT, START)).toEqual({
      outcome: "retry",
      reason: "generation_failed",
    });
  });

  test("a hold still live from an earlier attempt waits; a refusal fails", async () => {
    const live = deps(async () => ({ content: CONTENT }), {
      reserve: "in_progress",
    });
    expect(await writeNotebook(live.d, CONTEXT, START)).toEqual({
      outcome: "retry",
      reason: "usage_in_progress",
    });
    const spent = deps(async () => ({ content: CONTENT }), {
      reserve: "allowance_exhausted",
    });
    expect(await writeNotebook(spent.d, CONTEXT, START)).toEqual({
      outcome: "failed",
      reason: "allowance_exhausted",
    });
  });

  test("a lesson the owner cannot see, or one with no text, fails", async () => {
    const gone = deps(async () => ({ content: CONTENT }), { lessons: [] });
    expect(await writeNotebook(gone.d, CONTEXT, START)).toEqual({
      outcome: "failed",
      reason: "lesson_unavailable",
    });
    const empty = deps(async () => ({ content: CONTENT }), {
      lessons: [{ ...LESSON, body: "short" }],
    });
    expect(await writeNotebook(empty.d, CONTEXT, START)).toEqual({
      outcome: "failed",
      reason: "no_readable_material",
    });
  });

  test("the owner's names are replaced in everything sent (ADR-0043)", async () => {
    const sent: unknown[] = [];
    const { d } = deps(async (...args: never[]) => {
      sent.push(args);
      return { content: CONTENT };
    }, {
      lessons: [{
        ...LESSON,
        title: "Layla Haddad's notes",
        body: "Mr Omar Khalil asked Layla Haddad and Sami Nasser to explain " +
          "photosynthesis; her father Karim Haddad helped her revise.",
      }],
      names: async () => ({
        outcome: "ok",
        names: [
          { name: "Layla Haddad", kind: "self" },
          { name: "Sami Nasser", kind: "classmate" },
          { name: "Omar Khalil", kind: "teacher" },
          { name: "Karim Haddad", kind: "parent" },
        ],
      }),
    });
    expect(
      await writeNotebook(d, CONTEXT, {
        ...START,
        lessonTitle: "Layla Haddad's notes",
      }),
    ).toMatchObject({ outcome: "ready" });
    const text = JSON.stringify(sent);
    for (
      const name of ["Layla", "Haddad", "Sami", "Nasser", "Omar", "Khalil"]
    ) {
      expect(text).not.toContain(name);
    }
    expect(text).not.toContain("Karim");
    for (
      const placeholder of ["[student]", "[classmate]", "[teacher]", "[parent]"]
    ) {
      expect(text).toContain(placeholder);
    }
    expect(text).toContain("photosynthesis");
  });

  test("names that cannot be read fail it: no hold, no model call", async () => {
    for (
      const names of [
        async () => ({ outcome: "forbidden" }),
        async () => ({ outcome: "ok" }),
        () => Promise.reject(new Error("connection reset")),
      ]
    ) {
      let called = 0;
      const { d, ledger } = deps(async () => {
        called++;
        return { content: CONTENT };
      }, { names });
      expect(await writeNotebook(d, CONTEXT, START)).toEqual({
        outcome: "failed",
        reason: "names_unavailable",
      });
      expect(called).toBe(0);
      expect(ledger).toEqual([]);
    }
  });

  test("an owner who may no longer use AI fails it, with no model call", async () => {
    expect(AI_ACCESS_FAILURES).toEqual([
      "not_student",
      "no_class",
      "consent_required",
      "guardian_consent_required",
    ]);
    for (const refusal of AI_ACCESS_FAILURES) {
      let called = 0;
      const { d, ledger } = deps(async () => {
        called++;
        return { content: CONTENT };
      }, { reserve: refusal });
      // Failed, not retried: the reason the student is shown.
      expect(await writeNotebook(d, CONTEXT, START)).toEqual({
        outcome: "failed",
        reason: refusal,
      });
      expect(called).toBe(0);
      expect(ledger.map((l) => l.operation)).toEqual(["reserve"]);
    }
  });

  test("without a provider it fails as unavailable", async () => {
    const { d } = deps(async () => ({ content: CONTENT }));
    expect(await writeNotebook({ ...d, assistant: null }, CONTEXT, START))
      .toEqual({ outcome: "failed", reason: "provider_unavailable" });
  });
});

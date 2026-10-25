import { describe, expect, test } from "bun:test";
import type { MarkingVerdict } from "@studafy/domain";
import {
  type PrivateFileStorage,
  sha256Hex,
  StudyAssistantError,
} from "@studafy/infrastructure";
import { createJsonLogger } from "@studafy/observability";
import {
  createMarkingSuggestionsProcessor,
  type MarkingJob,
  type MarkingQueue,
} from "../src/processors/markingSuggestions";

// The marking processor against a stand-in queue (ADR-0046): it makes a
// suggestion only for a teacher who still teaches the class and holds the
// plan, keeps every roster name out of the model call, meters each call in
// the teacher's ledger first, never calls the model without a reference or
// any work, reads only the bytes the scan cleared, and stops on a job
// another worker took. The SQL is supabase/tests/marking_suggestions.sql.

const VERDICT: MarkingVerdict = {
  suggestedScore: 3,
  met: ["Names light"],
  missed: ["Names oxygen"],
  rationale: "Two of three.",
  feedback: "Say what the plant gives off.",
  conflict: null,
  reviewReason: null,
};

function job(overrides: Partial<MarkingJob> = {}): MarkingJob {
  return {
    id: "job-1",
    attempt: 1,
    teacherId: "teacher",
    studentId: "student",
    maximumScore: 5,
    strictness: "balanced",
    referenceVersion: 2,
    limits: { pagesPerHandIn: 20, handInChars: 60_000 },
    question: {
      questionId: "q1",
      kind: "essay",
      prompt: "Explain photosynthesis.",
      maximumScore: 5,
      preferredAnswer: "Light, water and CO2 make glucose and oxygen.",
      markingGuidance: null,
      keyPoints: [{ text: "Names light" }],
      acceptedMethods: null,
      partialCredit: null,
    },
    answerText: "Layla Haddad: plants use light from the sun.",
    files: [],
    names: [{ name: "Layla Haddad", kind: "self" }],
    planActive: true,
    teaches: true,
    ...overrides,
  };
}

function fakeQueue(options: { reserve?: Record<string, unknown> } = {}) {
  const usage: string[] = [];
  const finished: {
    outcome: string;
    result: Record<string, unknown>;
  }[] = [];
  const queue: MarkingQueue = {
    claim: async () => [],
    usage: async (_w, _j, operation) => {
      usage.push(operation);
      if (operation === "reserve") {
        return options.reserve ?? { outcome: "ok", usageId: "u1" };
      }
      return { outcome: "ok" };
    },
    finish: async (_w, _j, outcome, result) => {
      finished.push({ outcome, result });
      return { outcome: "ok" };
    },
    backlog: async () => ({}),
    purge: async () => ({}),
  };
  return { queue, usage, finished };
}

function processorWith(
  queue: MarkingQueue,
  options: {
    mark?: () => Promise<{ verdict: MarkingVerdict }>;
    storage?: PrivateFileStorage;
    sent?: string[];
  } = {},
) {
  return createMarkingSuggestionsProcessor({
    queue,
    storage: options.storage ??
      ({ openObject: () => Promise.reject(new Error("no files")) } as never),
    assistant: {
      markAnswer: async (_reference, answer) => {
        options.sent?.push(answer);
        return options.mark ? await options.mark() : {
          verdict: VERDICT,
          usage: { inputTokens: 900, outputTokens: 120, model: "stub" },
        };
      },
      transcribe: async () => ({ answer: "Handwritten: light makes sugar." }),
    },
    prices: { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 },
    logger: createJsonLogger("worker", "test", "error"),
    concurrency: 2,
  });
}

describe("marking suggestions", () => {
  test("a suggestion is metered, made without names, and reported", async () => {
    const { queue, usage, finished } = fakeQueue();
    const sent: string[] = [];
    await processorWith(queue, { sent }).process(job());
    expect(usage).toEqual(["reserve", "settle"]);
    expect(sent[0]).not.toContain("Layla");
    expect(sent[0]).toContain("[student]");
    expect(finished[0]!.outcome).toBe("ready");
    expect(finished[0]!.result).toMatchObject({
      suggestedScore: 3,
      met: ["Names light"],
      model: "stub",
    });
  });

  test("a teacher who left the class or lost the plan sends nothing", async () => {
    for (
      const [overrides, reason] of [
        [{ teaches: false }, "not_teacher"],
        [{ planActive: false }, "plan_inactive"],
      ] as const
    ) {
      const { queue, usage, finished } = fakeQueue();
      const sent: string[] = [];
      await processorWith(queue, { sent }).process(job(overrides));
      expect(sent).toEqual([]);
      expect(usage).toEqual([]);
      expect(finished[0]).toEqual({ outcome: "skipped", result: { reason } });
    }
  });

  test("no reference, or no work, is for the teacher - not the model", async () => {
    const cases: [Partial<MarkingJob>, string][] = [
      [{ question: null }, "no_reference"],
      [{
        question: {
          ...job().question!,
          preferredAnswer: null,
          keyPoints: [],
        },
      }, "no_reference"],
      [{ answerText: "   " }, "empty"],
    ];
    for (const [overrides, review] of cases) {
      const { queue, usage, finished } = fakeQueue();
      await processorWith(queue).process(job(overrides));
      expect(usage).toEqual([]);
      expect(finished[0]!.outcome).toBe("ready");
      expect(finished[0]!.result).toMatchObject({
        suggestedScore: null,
        reviewReason: review,
      });
    }
  });

  test("past the monthly allowance the job fails without a model call", async () => {
    const { queue, finished } = fakeQueue({
      reserve: { outcome: "allowance_exhausted" },
    });
    const sent: string[] = [];
    await processorWith(queue, { sent }).process(job());
    expect(sent).toEqual([]);
    expect(finished[0]).toEqual({
      outcome: "failed",
      result: { reason: "allowance_used" },
    });
  });

  test("a lost lease stops the job without reporting", async () => {
    const { queue, finished } = fakeQueue({
      reserve: { outcome: "lease_lost" },
    });
    expect(await processorWith(queue).process(job())).toBe("lease_lost");
    expect(finished).toEqual([]);
  });

  test("a busy provider is tried again, and an unbilled hold released", async () => {
    const { queue, usage, finished } = fakeQueue();
    await processorWith(queue, {
      mark: () => Promise.reject(new StudyAssistantError("unavailable", 503)),
    }).process(job());
    expect(usage).toEqual(["reserve", "release"]);
    expect(finished[0]).toEqual({
      outcome: "retry",
      result: { reason: "model_unavailable" },
    });
  });

  test("a hand-in photo is read only if its bytes are the ones scanned", async () => {
    // A tiny JPEG header is enough: prepareImage is not reached when the
    // digest differs, and the file then counts as unreadable.
    const bytes = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
    const storage = {
      openObject: () => Promise.resolve({ bytes, sizeBytes: bytes.length }),
    } as unknown as PrivateFileStorage;
    const file = {
      fileId: "f1",
      bucket: "b",
      objectKey: "k",
      storedSha256: "0".repeat(64),
      mediaType: "image/jpeg",
      rootClean: true,
    };
    const { queue, finished } = fakeQueue();
    const sent: string[] = [];
    await processorWith(queue, { storage, sent }).process(
      job({
        answerText: null,
        question: { ...job().question!, questionId: null },
        files: [file],
      }),
    );
    expect(sent).toEqual([]);
    expect(finished[0]!.result).toMatchObject({
      suggestedScore: null,
      reviewReason: "unreadable",
    });
    expect(await sha256Hex(bytes)).not.toBe(file.storedSha256);
  });
});

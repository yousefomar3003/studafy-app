import { describe, expect, test } from "bun:test";
import type { NotebookContent } from "@studafy/domain";
import type {
  NotebookWriteResult,
  StudyAssistant,
} from "@studafy/infrastructure";
import { createJsonLogger } from "@studafy/observability";
import {
  createNotebookGenerationProcessor,
  type NotebookJob,
  type NotebookQueue,
  startNotebookGeneration,
} from "../src/processors/notebookGeneration";

// The notebook processor against a stand-in queue: what it reports, that it
// stops acting on a job another worker took, that it never writes more
// notebooks at once than it is allowed, that the owner's names are kept out
// of the model call and that a ledger refusal fails the notebook without
// one (ADR-0043). The real SQL is notebookGeneration.integration.test.ts.

const LESSON = {
  resourceId: "lesson-1",
  versionId: "v1",
  classroomId: "c1",
  grade: "8",
  title: "Photosynthesis",
  body: "Photosynthesis turns light into chemical energy in chloroplasts.",
  sources: [],
};

function job(n: number): NotebookJob {
  return {
    jobId: `job-${n}`,
    attempt: 1,
    ownerId: "student",
    schoolId: "school",
    start: { notebookId: `nb-${n}`, generation: 1, resourceId: "lesson-1" },
  };
}

function fakeQueue(
  waiting: NotebookJob[],
  options: {
    leaseLost?: boolean;
    names?: Record<string, unknown>;
    reserve?: Record<string, unknown>;
  } = {},
) {
  const usage: string[] = [];
  const finished: { jobId: string; result: NotebookWriteResult }[] = [];
  const claims: number[] = [];
  const queue: NotebookQueue = {
    claim: async (_worker, limit) => {
      claims.push(limit);
      return waiting.splice(0, limit);
    },
    material: async () =>
      options.leaseLost
        ? { outcome: "lease_lost" }
        : { outcome: "ok", lessons: [LESSON] },
    usage: async (_worker, _claim, operation) => {
      usage.push(operation);
      return operation === "reserve" && options.reserve
        ? options.reserve
        : { outcome: "ok", usageId: "u" };
    },
    names: async () =>
      options.leaseLost
        ? { outcome: "lease_lost" }
        : options.names ?? { outcome: "ok", names: [] },
    finish: async (_worker, claim, result) => {
      finished.push({ jobId: claim.jobId, result });
      return options.leaseLost
        ? { outcome: "lease_lost" }
        : { outcome: "ok", state: "done" };
    },
    backlog: async () => ({ pending: waiting.length, deadLetters: 0 }),
  };
  return { queue, finished, claims, usage };
}

const events: string[] = [];
const logger = createJsonLogger("worker", "test", "debug", (line) => {
  events.push(String((JSON.parse(line) as { event: string }).event));
});

describe("notebook processor", () => {
  test("writes a claimed notebook and reports it", async () => {
    const { queue, finished } = fakeQueue([job(1)]);
    const assistant = {
      notebook: async () => ({
        content: { overview: "x" } as unknown as NotebookContent,
      }),
    } as Pick<StudyAssistant, "notebook">;
    const processor = createNotebookGenerationProcessor({
      queue,
      assistant,
      prices: { inputUsdPerMTok: 1, outputUsdPerMTok: 1 },
      logger,
      concurrency: 2,
    });
    expect(await processor.runOnce()).toBe(1);
    expect(finished).toMatchObject([{
      jobId: "job-1",
      result: { outcome: "ready" },
    }]);
    expect(events).toContain("study_notebook_job");
  });

  test("a job another worker took is left to it, with no model call", async () => {
    const { queue } = fakeQueue([job(2)], { leaseLost: true });
    let called = 0;
    const processor = createNotebookGenerationProcessor({
      queue,
      assistant: {
        notebook: async () => {
          called++;
          return { content: {} as NotebookContent };
        },
      },
      prices: { inputUsdPerMTok: 1, outputUsdPerMTok: 1 },
      logger,
      concurrency: 1,
    });
    await processor.runOnce();
    expect(called).toBe(0);
    expect(events).toContain("study_notebook_lease_lost");
  });

  test("the owner's names are replaced in the notebook request", async () => {
    const { queue, finished } = fakeQueue([job(3)], {
      names: {
        outcome: "ok",
        names: [
          { name: "Layla Haddad", kind: "self" },
          { name: "Sami Nasser", kind: "classmate" },
          { name: "Omar Khalil", kind: "teacher" },
          { name: "Huda Saleh", kind: "parent" },
        ],
      },
    });
    queue.material = async () => ({
      outcome: "ok",
      lessons: [{
        ...LESSON,
        title: "Layla Haddad revises",
        body: "Omar Khalil asked Layla Haddad and Sami Nasser how " +
          "chloroplasts capture light. Huda Saleh helped at home.",
      }],
    });
    const sent: string[] = [];
    const processor = createNotebookGenerationProcessor({
      queue,
      assistant: {
        notebook: async (title, passages, extras) => {
          sent.push(JSON.stringify({ title, passages, extras }));
          return { content: { overview: "x" } as unknown as NotebookContent };
        },
      },
      prices: { inputUsdPerMTok: 1, outputUsdPerMTok: 1 },
      logger,
      concurrency: 1,
    });
    await processor.runOnce();
    expect(finished).toMatchObject([{ result: { outcome: "ready" } }]);
    expect(sent).toHaveLength(1);
    for (
      const word of ["Layla", "Haddad", "Sami", "Nasser", "Omar", "Khalil"]
    ) {
      expect(sent[0]).not.toContain(word);
    }
    expect(sent[0]).not.toContain("Huda");
    expect(sent[0]).toContain("[student] revises");
    expect(sent[0]).toContain(
      "[teacher] asked [student] and [classmate] how chloroplasts",
    );
    expect(sent[0]).toContain("[parent] helped");
  });

  test("names that cannot be read: no model call, the notebook fails", async () => {
    const { queue, finished, usage } = fakeQueue([job(4)], {
      names: { outcome: "invalid" },
    });
    let called = 0;
    const processor = createNotebookGenerationProcessor({
      queue,
      assistant: {
        notebook: async () => {
          called++;
          return { content: {} as NotebookContent };
        },
      },
      prices: { inputUsdPerMTok: 1, outputUsdPerMTok: 1 },
      logger,
      concurrency: 1,
    });
    await processor.runOnce();
    expect(called).toBe(0);
    expect(usage).toEqual([]);
    expect(finished).toEqual([{
      jobId: "job-4",
      result: { outcome: "failed", reason: "names_unavailable" },
    }]);
  });

  test("a refused ledger reserve fails the notebook with no provider call", async () => {
    for (const refusal of ["consent_required", "no_class"]) {
      const { queue, finished, usage } = fakeQueue([job(5)], {
        reserve: { outcome: refusal },
      });
      let called = 0;
      const processor = createNotebookGenerationProcessor({
        queue,
        assistant: {
          notebook: async () => {
            called++;
            return { content: {} as NotebookContent };
          },
        },
        prices: { inputUsdPerMTok: 1, outputUsdPerMTok: 1 },
        logger,
        concurrency: 1,
      });
      await processor.runOnce();
      expect(called).toBe(0);
      // Held nothing, so nothing to settle or release.
      expect(usage).toEqual(["reserve"]);
      // Failed - not "retry" - with the reason the app shows.
      expect(finished).toEqual([{
        jobId: "job-5",
        result: { outcome: "failed", reason: refusal },
      }]);
    }
  });

  test("never writes more at once than its concurrency", async () => {
    const { queue, claims } = fakeQueue(
      Array.from({ length: 6 }, (_, i) => job(10 + i)),
    );
    let running = 0;
    let most = 0;
    const release: (() => void)[] = [];
    const running$ = startNotebookGeneration(
      {
        queue,
        assistant: {
          notebook: async () => {
            running++;
            most = Math.max(most, running);
            await new Promise<void>((resolve) => release.push(resolve));
            running--;
            return { content: { overview: "x" } as unknown as NotebookContent };
          },
        },
        prices: { inputUsdPerMTok: 1, outputUsdPerMTok: 1 },
        logger,
        concurrency: 2,
      },
      10,
      { closeWaitMs: 1_000 },
    );
    try {
      for (let i = 0; i < 50 && release.length < 2; i++) await Bun.sleep(10);
      await Bun.sleep(50);
      expect(most).toBe(2);
      expect(running$.inFlight()).toBe(2);
      expect(claims.every((limit) => limit <= 2)).toBe(true);
      // As each finishes, the next is claimed.
      while (release.length > 0) {
        release.shift()!();
        await Bun.sleep(30);
      }
    } finally {
      await running$.close();
    }
    expect(most).toBe(2);
  });
});

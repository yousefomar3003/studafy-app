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
// stops acting on a job another worker took, and that it never writes more
// notebooks at once than it is allowed. The real SQL is
// notebookGeneration.integration.test.ts.

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
  options: { leaseLost?: boolean } = {},
) {
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
    usage: async () => ({ outcome: "ok", usageId: "u" }),
    finish: async (_worker, claim, result) => {
      finished.push({ jobId: claim.jobId, result });
      return options.leaseLost
        ? { outcome: "lease_lost" }
        : { outcome: "ok", state: "done" };
    },
    backlog: async () => ({ pending: waiting.length, deadLetters: 0 }),
  };
  return { queue, finished, claims };
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

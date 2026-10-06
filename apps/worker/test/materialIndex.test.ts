import { describe, expect, test } from "bun:test";
import { createCanvas } from "@napi-rs/canvas";
import { DOCX_MEDIA_TYPE } from "@studafy/domain";
import { type PrivateFileStorage, sha256Hex } from "@studafy/infrastructure";
import { buildDocx, buildPdf } from "@studafy/test-support";
import {
  createMaterialIndexProcessor,
  type MaterialJob,
  type MaterialQueue,
} from "../src/processors/materialIndex";

/**
 * The background reader (ADR-0037): which bytes it reads, what it reports
 * back, and that a passing failure is retried rather than marked unreadable.
 */

const logger = {
  info() {},
  warn() {},
  error() {},
  debug() {},
} as never;

const limits = {
  ocrPagesPerFile: 60,
  textPagesPerFile: 500,
  charsPerDocument: 600_000,
  linkMaxBytes: 3_000_000,
};

class FakeQueue implements MaterialQueue {
  finished: Record<string, unknown>[] = [];
  asked: number[] = [];
  constructor(private jobs: MaterialJob[], private pages = 60) {}
  claim() {
    const next = this.jobs.splice(0, 1);
    return Promise.resolve(next);
  }
  ocrAllowance(_: string, __: string, pages: number) {
    this.asked.push(pages);
    return Promise.resolve(Math.min(pages, this.pages));
  }
  finish(_: string, __: string, result: Record<string, unknown>) {
    this.finished.push(result);
    return Promise.resolve(true);
  }
}

function storageOf(bytes: Uint8Array): PrivateFileStorage {
  return {
    openObject: () => Promise.resolve({ bytes, sizeBytes: bytes.length }),
  } as unknown as PrivateFileStorage;
}

async function job(
  bytes: Uint8Array,
  mediaType: string,
  overrides: Partial<NonNullable<MaterialJob["file"]>> = {},
): Promise<MaterialJob> {
  return {
    docId: crypto.randomUUID(),
    schoolId: crypto.randomUUID(),
    attempt: 1,
    kind: "file",
    url: null,
    file: {
      bucket: "private-school-files",
      objectKey: "clean/v1/x",
      storedSha256: await sha256Hex(bytes),
      mediaType,
      rootClean: true,
      ...overrides,
    },
  };
}

const prices = { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 };

describe("material index worker", () => {
  test("a Word file is read into passages, with no model call", async () => {
    const bytes = buildDocx([{ heading: "Cells" }, {
      paragraph: "A cell is the unit of life.",
    }]);
    const queue = new FakeQueue([await job(bytes, DOCX_MEDIA_TYPE)]);
    let calls = 0;
    const processor = createMaterialIndexProcessor({
      queue,
      storage: storageOf(bytes),
      assistant: {
        transcribe: () => {
          calls++;
          return Promise.resolve({ answer: "x" });
        },
      },
      limits,
      prices,
      logger,
    });
    expect(await processor.runOnce()).toBe(1);
    expect(calls).toBe(0);
    expect(queue.finished[0]).toMatchObject({
      outcome: "ready",
      extractor: "docx-v1",
      chunks: [{ heading: "Cells", body: "A cell is the unit of life." }],
      usage: [],
    });
  });

  test("bytes that do not match the scanned digest are never read", async () => {
    const bytes = buildDocx([{ paragraph: "x" }]);
    const queue = new FakeQueue([
      await job(bytes, DOCX_MEDIA_TYPE, { storedSha256: "0".repeat(64) }),
    ]);
    const processor = createMaterialIndexProcessor({
      queue,
      storage: storageOf(bytes),
      assistant: null,
      limits,
      prices,
      logger,
    });
    await processor.runOnce();
    expect(queue.finished[0]).toEqual({
      outcome: "retry",
      reason: "stored_object_mismatch",
    });
  });

  test("a file the scan has not cleared waits", async () => {
    const bytes = buildDocx([{ paragraph: "x" }]);
    const queue = new FakeQueue([
      await job(bytes, DOCX_MEDIA_TYPE, { rootClean: false }),
    ]);
    const processor = createMaterialIndexProcessor({
      queue,
      storage: storageOf(bytes),
      assistant: null,
      limits,
      prices,
      logger,
    });
    await processor.runOnce();
    expect(queue.finished[0]).toEqual({
      outcome: "retry",
      reason: "not_scanned",
    });
  });

  test("a scanned page is read by the model and its cost recorded", async () => {
    const canvas = createCanvas(300, 200);
    canvas.getContext("2d").fillRect(0, 0, 50, 50);
    const bytes = buildPdf([{
      jpeg: new Uint8Array(await canvas.encode("jpeg", 80)),
      width: 300,
      height: 200,
    }]);
    const queue = new FakeQueue([await job(bytes, "application/pdf")]);
    const processor = createMaterialIndexProcessor({
      queue,
      storage: storageOf(bytes),
      assistant: {
        transcribe: (_, mediaType, kind) => {
          expect([mediaType, kind]).toEqual(["image/jpeg", "page"]);
          return Promise.resolve({
            answer: "دورة كالفن تثبت ثاني أكسيد الكربون.",
            usage: {
              inputTokens: 1000,
              outputTokens: 100,
              model: "Qwen/Qwen3.5-9B",
            },
          });
        },
      },
      limits,
      prices,
      logger,
    });
    await processor.runOnce();
    expect(queue.asked).toEqual([1]);
    expect(queue.finished[0]).toMatchObject({
      outcome: "ready",
      chunks: [{ page: 1, body: "دورة كالفن تثبت ثاني أكسيد الكربون." }],
      // 1000 × 0.17 + 100 × 0.25 micro-dollars.
      usage: [{
        kind: "ocr",
        pages: 1,
        inputTokens: 1000,
        outputTokens: 100,
        costMicroUsd: 195,
      }],
    });
  });

  test("the model being unavailable is retried, not marked unreadable", async () => {
    const canvas = createCanvas(300, 200);
    const bytes = buildPdf([{
      jpeg: new Uint8Array(await canvas.encode("jpeg", 80)),
      width: 300,
      height: 200,
    }]);
    const queue = new FakeQueue([await job(bytes, "application/pdf")]);
    const processor = createMaterialIndexProcessor({
      queue,
      storage: storageOf(bytes),
      assistant: {
        transcribe: () =>
          Promise.reject(
            Object.assign(new Error("down"), { kind: "unavailable" }),
          ),
      },
      limits,
      prices,
      logger,
    });
    await processor.runOnce();
    expect(queue.finished[0]).toEqual({
      outcome: "retry",
      reason: "model_unavailable",
    });
  });

  test("the limits set in SQL override the worker's defaults", async () => {
    const bytes = buildDocx([{ paragraph: "word ".repeat(2000) }]);
    const claimed = {
      ...(await job(bytes, DOCX_MEDIA_TYPE)),
      limits: { charsPerDocument: 1000 },
    };
    const queue = new FakeQueue([claimed]);
    const processor = createMaterialIndexProcessor({
      queue,
      storage: storageOf(bytes),
      assistant: null,
      limits,
      prices,
      logger,
    });
    await processor.runOnce();
    expect(queue.finished[0]).toMatchObject({
      outcome: "ready",
      reason: "partly_read",
    });
  });
});

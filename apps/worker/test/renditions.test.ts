import { describe, expect, test } from "bun:test";
import {
  DOC_MEDIA_TYPE,
  DOCX_MEDIA_TYPE,
  PPTX_MEDIA_TYPE,
} from "@studafy/domain";
import {
  type ConversionResult,
  ConverterUnavailableError,
  type ConvertFrom,
  type ConvertTo,
  type DocumentConverter,
  type RenditionStorage,
  sha256Hex,
  StorageUnavailableError,
} from "@studafy/infrastructure";
import { buildDocx, buildPptx, buildZip } from "@studafy/test-support";
import {
  createRenditionProcessor,
  type RenditionDeletion,
  type RenditionJob,
  type RenditionQueue,
  type RenditionResult,
  startRenditions,
} from "../src/processors/renditions";

/**
 * The rendition worker (DL-078): what it converts, what it stores, what it
 * refuses to store, and that a passing failure is retried, never stored.
 */

const lines: { event: string; fields: Record<string, unknown> }[] = [];
const logger = {
  info: (event: string, fields: Record<string, unknown> = {}) =>
    lines.push({ event, fields }),
  warn: (event: string, fields: Record<string, unknown> = {}) =>
    lines.push({ event, fields }),
  error: (event: string, fields: Record<string, unknown> = {}) =>
    lines.push({ event, fields }),
  debug() {},
} as never;

const SOURCE = buildDocx([{ paragraph: "Secret lesson text." }]);
const PDF = new TextEncoder().encode(
  "%PDF-1.7\n1 0 obj\n<< /Type /Catalog /OpenAction [3 0 R /XYZ null null 0] >>\nendobj\nstartxref\n0\n%%EOF\n",
);

class FakeQueue implements RenditionQueue {
  finished: { id: string; result: RenditionResult }[] = [];
  deletionsFinished: { id: number; ok: boolean }[] = [];
  requeued = 0;
  answer: "recorded" | "lost" | "gone" = "recorded";
  constructor(
    public jobs: RenditionJob[] = [],
    public deletions: RenditionDeletion[] = [],
  ) {}
  claim(_: string, limit: number) {
    return Promise.resolve(this.jobs.splice(0, limit));
  }
  finish(_: string, id: string, result: RenditionResult) {
    this.finished.push({ id, result });
    return Promise.resolve(this.answer);
  }
  requeueSkipped() {
    this.requeued++;
    return Promise.resolve(2);
  }
  claimDeletions(_: string, limit: number) {
    return Promise.resolve(this.deletions.splice(0, limit));
  }
  finishDeletion(_: string, id: number, ok: boolean) {
    this.deletionsFinished.push({ id, ok });
    return Promise.resolve(true);
  }
  backlog() {
    return Promise.resolve({ queued: 0 });
  }
}

class FakeStorage implements RenditionStorage {
  written = new Map<string, { bytes: Uint8Array; type: string }>();
  deleted: string[] = [];
  failDelete = false;
  constructor(public source: Uint8Array = SOURCE) {}
  openObject(_: string, key: string) {
    if (key.startsWith("quarantine/")) {
      return Promise.resolve({
        bytes: this.source,
        sizeBytes: this.source.length,
      });
    }
    return Promise.reject(new StorageUnavailableError());
  }
  delete(_: string, key: string) {
    if (this.failDelete) return Promise.reject(new StorageUnavailableError());
    this.deleted.push(key);
    return Promise.resolve();
  }
  writeRendition(_: string, key: string, bytes: Uint8Array, type: string) {
    this.written.set(key, { bytes, type });
    return Promise.resolve();
  }
}

class FakeConverter implements DocumentConverter {
  calls: { from: ConvertFrom; to: ConvertTo; bytes: Uint8Array }[] = [];
  constructor(
    private reply: (to: ConvertTo) => ConversionResult | Promise<never>,
  ) {}
  convert(bytes: Uint8Array, from: ConvertFrom, to: ConvertTo) {
    this.calls.push({ from, to, bytes });
    return Promise.resolve(this.reply(to));
  }
}

async function job(
  overrides: Partial<RenditionJob> = {},
): Promise<RenditionJob> {
  return {
    renditionId: crypto.randomUUID(),
    kind: "pdf_preview",
    attempt: 1,
    sourceMediaType: DOCX_MEDIA_TYPE,
    mediaType: "application/pdf",
    bucket: "private-school-files",
    objectKey: `renditions/v1/${crypto.randomUUID()}/${"a".repeat(32)}`,
    source: {
      bucket: "private-school-files",
      objectKey: `quarantine/v1/${crypto.randomUUID()}/${"b".repeat(32)}`,
      storedSha256: await sha256Hex(SOURCE),
      storedSizeBytes: SOURCE.length,
      clean: true,
    },
    ...overrides,
  };
}

function processor(
  queue: FakeQueue,
  storage: FakeStorage,
  converter: DocumentConverter | null,
) {
  return createRenditionProcessor({
    queue,
    storage,
    converter,
    logger,
    concurrency: 1,
  });
}

describe("rendition worker", () => {
  test("converts the scanned bytes to a PDF preview and stores it", async () => {
    const queue = new FakeQueue([await job()]);
    const storage = new FakeStorage();
    const converter = new FakeConverter(() => ({ ok: true, bytes: PDF }));
    expect(await processor(queue, storage, converter).runOnce()).toBe(1);
    expect(converter.calls.map((c) => [c.from, c.to])).toEqual([[
      "docx",
      "pdf",
    ]]);
    expect(converter.calls[0]!.bytes).toEqual(SOURCE);
    const [stored] = [...storage.written.values()];
    expect(stored).toEqual({ bytes: PDF, type: "application/pdf" });
    expect(queue.finished[0]!.result).toEqual({
      outcome: "ready",
      sha256: await sha256Hex(PDF),
      sizeBytes: PDF.length,
    });
  });

  test("an old .doc becomes a .docx for the material reader", async () => {
    const docx = buildDocx([{ paragraph: "Converted." }]);
    const queue = new FakeQueue([
      await job({
        kind: "ooxml",
        sourceMediaType: DOC_MEDIA_TYPE,
        mediaType: DOCX_MEDIA_TYPE,
      }),
    ]);
    const storage = new FakeStorage();
    const converter = new FakeConverter(() => ({ ok: true, bytes: docx }));
    await processor(queue, storage, converter).runOnce();
    expect(converter.calls.map((c) => [c.from, c.to])).toEqual([[
      "doc",
      "docx",
    ]]);
    expect([...storage.written.values()][0]!.type).toBe(DOCX_MEDIA_TYPE);
    expect(queue.finished[0]!.result.outcome).toBe("ready");
  });

  test("without a converter, renditions are skipped and nothing is read", async () => {
    const queue = new FakeQueue([await job()]);
    const storage = new FakeStorage();
    await processor(queue, storage, null).runOnce();
    expect(queue.finished[0]!.result).toEqual({
      outcome: "skipped",
      code: "converter_not_configured",
    });
    expect(storage.written.size).toBe(0);
  });

  test("bytes that do not match the scanned digest are never converted", async () => {
    const queue = new FakeQueue([await job()]);
    const storage = new FakeStorage(buildDocx([{ paragraph: "swapped" }]));
    const converter = new FakeConverter(() => ({ ok: true, bytes: PDF }));
    await processor(queue, storage, converter).runOnce();
    expect(converter.calls).toEqual([]);
    expect(queue.finished[0]!.result).toEqual({
      outcome: "retry",
      code: "stored_object_mismatch",
    });
  });

  test("output that fails the upload rules for its type is not stored", async () => {
    const macro = buildZip([
      {
        name: "[Content_Types].xml",
        data:
          '<Types><Default Extension="bin" ContentType="application/vnd.ms-office.vbaProject"/></Types>',
      },
      { name: "ppt/presentation.xml", data: "<p/>" },
      { name: "ppt/vbaProject.bin", data: "x" },
    ]);
    const outputs: [Partial<RenditionJob>, Uint8Array][] = [
      // A PDF that runs JavaScript.
      [
        {},
        new TextEncoder().encode(
          "%PDF-1.7\n<< /OpenAction << /S /JavaScript /JS (x) >> >>\nstartxref\n%%EOF\n",
        ),
      ],
      // Not a PDF at all.
      [{}, new TextEncoder().encode("<html></html>")],
      // A deck with a macro.
      [{
        kind: "ooxml",
        sourceMediaType: "application/vnd.ms-powerpoint",
        mediaType: PPTX_MEDIA_TYPE,
      }, macro],
      // The wrong format.
      [{
        kind: "ooxml",
        sourceMediaType: "application/vnd.ms-powerpoint",
        mediaType: PPTX_MEDIA_TYPE,
      }, buildDocx([{ paragraph: "x" }])],
    ];
    for (const [overrides, bytes] of outputs) {
      const queue = new FakeQueue([await job(overrides)]);
      const storage = new FakeStorage();
      await processor(
        queue,
        storage,
        new FakeConverter(() => ({ ok: true, bytes })),
      ).runOnce();
      expect(storage.written.size).toBe(0);
      expect(queue.finished[0]!.result).toEqual({
        outcome: "failed",
        code: "unsafe_output",
      });
    }
    // The real thing passes.
    const queue = new FakeQueue([
      await job({
        kind: "ooxml",
        sourceMediaType: "application/vnd.ms-powerpoint",
        mediaType: PPTX_MEDIA_TYPE,
      }),
    ]);
    await processor(
      queue,
      new FakeStorage(),
      new FakeConverter(() => ({
        ok: true,
        bytes: buildPptx([{ title: "A", lines: ["b"] }]),
      })),
    ).runOnce();
    expect(queue.finished[0]!.result.outcome).toBe("ready");
  });

  test("the converter's refusal fails the rendition with its code", async () => {
    const queue = new FakeQueue([await job()]);
    await processor(
      queue,
      new FakeStorage(),
      new FakeConverter(() => ({ ok: false, code: "conversion_timeout" })),
    ).runOnce();
    expect(queue.finished[0]!.result).toEqual({
      outcome: "failed",
      code: "conversion_timeout",
    });
  });

  test("an unavailable converter or storage is retried, nothing stored", async () => {
    const queue = new FakeQueue([await job()]);
    const storage = new FakeStorage();
    await processor(
      queue,
      storage,
      new FakeConverter(() =>
        Promise.reject(new ConverterUnavailableError(503))
      ),
    ).runOnce();
    expect(queue.finished[0]!.result).toEqual({
      outcome: "retry",
      code: "converter_unavailable",
    });
    const unreadable = new FakeQueue([
      await job({
        source: {
          bucket: "private-school-files",
          objectKey: "renditions/v1/not-a-source",
          storedSha256: "0".repeat(64),
          storedSizeBytes: 1,
          clean: true,
        },
      }),
    ]);
    await processor(
      unreadable,
      storage,
      new FakeConverter(() => ({ ok: true, bytes: PDF })),
    ).runOnce();
    expect(unreadable.finished[0]!.result).toEqual({
      outcome: "retry",
      code: "storage_unavailable",
    });
    expect(storage.written.size).toBe(0);
  });

  test("a source no longer clean, or a type with no conversion, fails", async () => {
    for (
      const overrides of [
        { source: null },
        { sourceMediaType: "image/png" },
        { kind: "ooxml" as const, mediaType: "application/pdf" },
      ]
    ) {
      const queue = new FakeQueue([await job(overrides)]);
      const converter = new FakeConverter(() => ({ ok: true, bytes: PDF }));
      await processor(queue, new FakeStorage(), converter).runOnce();
      expect(converter.calls).toEqual([]);
      expect(queue.finished[0]!.result.outcome).toBe("failed");
    }
  });

  test("a file deleted while converting leaves no object behind", async () => {
    const queue = new FakeQueue([await job()]);
    queue.answer = "gone";
    const storage = new FakeStorage();
    await processor(
      queue,
      storage,
      new FakeConverter(() => ({ ok: true, bytes: PDF })),
    ).runOnce();
    expect(storage.deleted).toEqual([...storage.written.keys()]);
  });

  test("the deletion sweep deletes queued objects and retries failures", async () => {
    const deletions = [
      {
        deletionId: 1,
        bucket: "private-school-files",
        objectKey: "renditions/v1/a",
      },
      {
        deletionId: 2,
        bucket: "private-school-files",
        objectKey: "renditions/v1/b",
      },
    ];
    const queue = new FakeQueue([], [...deletions]);
    const storage = new FakeStorage();
    expect(await processor(queue, storage, null).sweepDeletions()).toBe(2);
    expect(storage.deleted).toEqual(["renditions/v1/a", "renditions/v1/b"]);
    expect(queue.deletionsFinished).toEqual([{ id: 1, ok: true }, {
      id: 2,
      ok: true,
    }]);
    const failing = new FakeQueue([], [deletions[0]!]);
    const broken = new FakeStorage();
    broken.failDelete = true;
    await processor(failing, broken, null).sweepDeletions();
    expect(failing.deletionsFinished).toEqual([{ id: 1, ok: false }]);
  });

  test("logs carry ids, kinds and codes - never names or contents", async () => {
    lines.length = 0;
    const queue = new FakeQueue([await job()]);
    await processor(
      queue,
      new FakeStorage(),
      new FakeConverter(() => ({ ok: true, bytes: PDF })),
    ).runOnce();
    const text = JSON.stringify(lines);
    expect(text).toContain("rendition_finished");
    expect(text).not.toContain("Secret lesson text");
    expect(text).not.toContain("quarantine/");
  });

  test("the poller requeues skipped work once a converter is set, and closes", async () => {
    const queue = new FakeQueue([await job()]);
    const storage = new FakeStorage();
    const runtime = startRenditions({
      queue,
      storage,
      converter: new FakeConverter(() => ({ ok: true, bytes: PDF })),
      logger,
      concurrency: 1,
    }, 60_000);
    for (let i = 0; i < 50 && queue.finished.length === 0; i++) {
      await Bun.sleep(5);
    }
    await runtime.close();
    expect(queue.requeued).toBe(1);
    expect(queue.finished[0]!.result.outcome).toBe("ready");

    const idle = new FakeQueue();
    const withoutConverter = startRenditions({
      queue: idle,
      storage,
      converter: null,
      logger,
      concurrency: 1,
    }, 60_000);
    await Bun.sleep(5);
    await withoutConverter.close();
    expect(idle.requeued).toBe(0);
  });
});

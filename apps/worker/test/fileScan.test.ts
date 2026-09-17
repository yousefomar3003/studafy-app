import { describe, expect, test } from "bun:test";
import type {
  FileScanner,
  FileScanResult,
  ObservedObject,
  PrivateFileStorage,
} from "@studafy/infrastructure";
import { FileSecurityScanner, sha256Hex } from "@studafy/infrastructure";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import {
  createFileScanProcessor,
  type ScanFinish,
  type ScanJob,
  type ScanQueue,
} from "../src/processors/fileScan";

const encoder = new TextEncoder();
const PDF = encoder.encode(
  "%PDF-1.7\n1 0 obj\n<< /Type /Catalog >>\nendobj\n" +
    "trailer\n<< /Size 2 >>\nstartxref\n0\n%%EOF\n",
);

/** Minimal JPEG with an EXIF segment, so the scan transform rewrites it. */
function jpegWithExif(): Uint8Array {
  const parts: number[] = [0xff, 0xd8];
  const emit = (marker: number, payload: number[]) =>
    parts.push(
      0xff,
      marker,
      (payload.length + 2) >> 8,
      (payload.length + 2) & 0xff,
      ...payload,
    );
  emit(0xe1, [...encoder.encode("Exif\0\0GPS 51.5N")]);
  emit(0xdb, [0x00, 1, 2, 3]);
  emit(0xc0, [8, 1, 1, 1, 1, 1]);
  emit(0xc4, [0x00, 0x01]);
  parts.push(0xff, 0xda, 0x00, 0x04, 0x01, 0x00, 0x12, 0x34, 0x56, 0x78);
  parts.push(0xff, 0xd9);
  return Uint8Array.from(parts);
}

class FakeQueue implements ScanQueue {
  finishes: ScanFinish[] = [];
  transforms: string[] = [];
  jobs: ScanJob[] = [];
  lose = false;
  async claim() {
    const jobs = this.jobs;
    this.jobs = [];
    return jobs;
  }
  async recordTransform(_worker: string, _job: number, sha: string) {
    this.transforms.push(sha);
    return !this.lose;
  }
  async finish(_worker: string, _job: number, result: ScanFinish) {
    this.finishes.push(result);
    return true;
  }
  async backlog() {
    return { quarantined: 1, oldestQuarantineSeconds: 30 };
  }
}

class FakeStorage implements PrivateFileStorage {
  written: Uint8Array | null = null;
  readbackOverride: ObservedObject | null = null;
  failOpen = false;
  constructor(public bytes: Uint8Array) {}
  createUploadCapability(): never {
    throw new Error("not used");
  }
  async inspect(): Promise<ObservedObject> {
    if (this.readbackOverride) return this.readbackOverride;
    return {
      exists: true,
      sizeBytes: this.bytes.byteLength,
      sha256: await sha256Hex(this.bytes),
    };
  }
  async delete() {}
  async openObject() {
    if (this.failOpen) throw new Error("storage down");
    return { bytes: this.bytes, sizeBytes: this.bytes.byteLength };
  }
  async replaceObject(_b: string, _k: string, bytes: Uint8Array) {
    this.written = bytes;
    this.bytes = bytes;
  }
}

async function job(bytes: Uint8Array, overrides: Partial<ScanJob> = {}) {
  return {
    jobId: 7,
    uploadId: "11111111-1111-4111-8111-111111111111",
    fileId: "22222222-2222-4222-8222-222222222222",
    schoolId: "33333333-3333-4333-8333-333333333333",
    purpose: "lesson_resource",
    bucket: "private-school-files",
    objectKey:
      "quarantine/v1/11111111-1111-4111-8111-111111111111/abcdefghijklmnopqrstuv",
    sizeBytes: bytes.byteLength,
    sha256: await sha256Hex(bytes),
    storedSha256: null,
    transformPolicyVersion: null,
    declaredMediaType: "application/pdf",
    detectedMediaType: "application/pdf",
    ...overrides,
  } satisfies ScanJob;
}

function run(
  queue: FakeQueue,
  storage: FakeStorage,
  scanner: FileScanner = new FileSecurityScanner(),
) {
  const collector = new LogCollector();
  const logger = createJsonLogger("worker", "test", "debug", collector.sink);
  return {
    collector,
    runOnce: () =>
      createFileScanProcessor(queue, storage, scanner, logger).runOnce(),
  };
}

describe("FILE-051 scan processor", () => {
  test("a clean pdf is reported clean with the verified stored digest", async () => {
    const queue = new FakeQueue();
    queue.jobs = [await job(PDF)];
    const storage = new FakeStorage(PDF);
    const { collector, runOnce } = run(queue, storage);
    expect(await runOnce()).toBe(1);
    expect(queue.finishes).toEqual([{
      outcome: "clean",
      scanPolicyVersion: "file051-v1",
      scanDurationMs: expect.any(Number),
      transformPolicyVersion: undefined,
      storedSha256: await sha256Hex(PDF),
      storedSizeBytes: PDF.byteLength,
    }]);
    expect(storage.written).toBeNull();
    expect(collector.events()).toContain("file_scan_backlog");
  });

  test("an image is recorded, rewritten, read back, then reported clean", async () => {
    const original = jpegWithExif();
    const queue = new FakeQueue();
    queue.jobs = [await job(original, { detectedMediaType: "image/jpeg" })];
    const storage = new FakeStorage(original);
    await run(queue, storage).runOnce();
    expect(storage.written).not.toBeNull();
    const storedSha = await sha256Hex(storage.written!);
    expect(queue.transforms).toEqual([storedSha]);
    expect(queue.finishes[0]).toMatchObject({
      outcome: "clean",
      storedSha256: storedSha,
      transformPolicyVersion: "file051-structural-strip-v1",
    });
    expect(new TextDecoder().decode(storage.written!)).not.toContain("GPS");
  });

  test("a retry after a lost finish recognises its own earlier write", async () => {
    const original = jpegWithExif();
    const first = new FakeQueue();
    first.jobs = [await job(original, { detectedMediaType: "image/jpeg" })];
    const storage = new FakeStorage(original);
    await run(first, storage).runOnce();
    const stored = storage.bytes;

    const retry = new FakeQueue();
    retry.jobs = [
      await job(original, {
        detectedMediaType: "image/jpeg",
        storedSha256: await sha256Hex(stored),
      }),
    ];
    await run(retry, storage).runOnce();
    expect(retry.finishes[0]?.outcome).toBe("clean");
    expect(retry.transforms).toEqual([]);
  });

  test("bytes matching neither digest are never scanned to clean", async () => {
    const queue = new FakeQueue();
    queue.jobs = [await job(PDF)];
    const storage = new FakeStorage(encoder.encode("%PDF-1.7 swapped"));
    await run(queue, storage).runOnce();
    expect(queue.finishes).toEqual([{
      outcome: "retry",
      errorCode: "stored_object_mismatch",
    }]);
  });

  for (
    const [name, override] of [
      ["missing digest", { exists: true, sizeBytes: 1 }],
      ["missing object", { exists: false }],
      ["different digest", {
        exists: true,
        sizeBytes: 1,
        sha256: "0".repeat(64),
      }],
    ] as const
  ) {
    test(`a read-back with a ${name} retries, never clean`, async () => {
      const original = jpegWithExif();
      const queue = new FakeQueue();
      queue.jobs = [await job(original, { detectedMediaType: "image/jpeg" })];
      const storage = new FakeStorage(original);
      storage.readbackOverride = override;
      await run(queue, storage).runOnce();
      expect(queue.finishes).toEqual([{
        outcome: "retry",
        errorCode: "stored_object_mismatch",
      }]);
    });
  }

  test("a lost claim before the overwrite leaves the object untouched", async () => {
    const original = jpegWithExif();
    const queue = new FakeQueue();
    queue.lose = true;
    queue.jobs = [await job(original, { detectedMediaType: "image/jpeg" })];
    const storage = new FakeStorage(original);
    await run(queue, storage).runOnce();
    expect(storage.written).toBeNull();
    expect(queue.finishes.map((finish) => finish.outcome)).toEqual(["retry"]);
  });

  test("malware is a terminal rejection", async () => {
    const eicar = encoder.encode(
      "X5O!P%@AP[4\\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*",
    );
    const queue = new FakeQueue();
    queue.jobs = [await job(eicar)];
    await run(queue, new FakeStorage(eicar)).runOnce();
    expect(queue.finishes[0]).toMatchObject({
      outcome: "rejected",
      errorCode: "malware_detected",
    });
  });

  test("the claimed type is ignored; only the detected type is scanned", async () => {
    const queue = new FakeQueue();
    queue.jobs = [
      await job(PDF, {
        declaredMediaType: "application/pdf",
        detectedMediaType: null,
      }),
    ];
    await run(queue, new FakeStorage(PDF)).runOnce();
    expect(queue.finishes[0]?.outcome).toBe("rejected");
  });

  test("scanner outage and storage outage both retry", async () => {
    const outage: FileScanner = {
      scan: async (): Promise<FileScanResult> => ({
        verdict: "infrastructure",
        scanPolicyVersion: "file051-v1",
        durationMs: 1,
        transformPolicyVersion: null,
        storedSha256: null,
        storedSizeBytes: null,
        storedBytes: null,
      }),
    };
    const queue = new FakeQueue();
    queue.jobs = [await job(PDF)];
    await run(queue, new FakeStorage(PDF), outage).runOnce();

    const down = new FakeStorage(PDF);
    down.failOpen = true;
    queue.jobs = [await job(PDF)];
    await run(queue, down).runOnce();
    expect(queue.finishes).toEqual([
      { outcome: "retry", errorCode: "SCAN_INFRASTRUCTURE" },
      { outcome: "retry", errorCode: "SCAN_INFRASTRUCTURE" },
    ]);
  });
});

/**
 * AI-072 (ADR-0026): the AI capability is removed, not disabled. These tests
 * are the removal-path form of the AI-072 test list: path/URL substitution
 * has no field to travel in, no route or permission names an AI capability,
 * and no source file can egress to an AI provider or read a credential that
 * would re-enable one.
 */
import { describe, expect, test } from "bun:test";
import { Glob } from "bun";
import {
  JobQueueName,
  V1_ROUTE_CATALOGUE,
  V1CorrectGradeRequest,
  V1CreateUploadIntentRequest,
  V1File,
  V1ReviewGradeRequest,
  V1UploadablePurpose,
} from "@studafy/contracts";
import {
  AUTH_HANDLER_PERMISSIONS,
  PERMISSIONS,
} from "../../src/authorization/catalogue";
import { RATE_LIMIT_FLOWS } from "../../src/platform/rate-limit/policies";

const repoRoot = `${import.meta.dir}/../../../..`;
const AI_WORD =
  /(^|[^a-z])(ai|coach|study-?coach|grading-?draft|propose)([^a-z]|$)/i;
const id = "a0720000-0000-4000-8000-000000000054";

describe("AI-072 route and policy surface", () => {
  test("no /v1 route names an AI, coach or proposal capability", () => {
    const offenders = V1_ROUTE_CATALOGUE
      .map((route) => route.path)
      .filter((path) =>
        path.split("/").some((segment) => AI_WORD.test(segment))
      );
    expect(offenders).toEqual([]);
  });

  test("no permission or protected handler is an AI capability", () => {
    expect(PERMISSIONS.filter((permission) => AI_WORD.test(permission)))
      .toEqual([]);
    expect(
      AUTH_HANDLER_PERMISSIONS.filter((declaration) =>
        AI_WORD.test(declaration.path) || AI_WORD.test(declaration.permission)
      ),
    ).toEqual([]);
  });

  test("no background queue is an AI queue", () => {
    expect(JobQueueName.options.filter((queue) => /^ai[-_]/i.test(queue)))
      .toEqual([]);
  });

  test("the rate-limit registry meters no AI flow", () => {
    expect(Object.keys(RATE_LIMIT_FLOWS).filter((flow) => /^ai/i.test(flow)))
      .toEqual([]);
  });
});

describe("AI-072 path and URL substitution is unrepresentable", () => {
  const review = { expectedVersion: 1, score: 5, feedback: null };

  test("grade review accepts no AI draft and no per-question AI scores", () => {
    expect(V1ReviewGradeRequest.safeParse(review).success).toBe(true);
    expect(V1ReviewGradeRequest.safeParse({ ...review, draftId: id }).success)
      .toBe(false);
    expect(
      V1ReviewGradeRequest.safeParse({
        ...review,
        questionScores: [{ questionId: id, score: 5, reason: null }],
      }).success,
    ).toBe(false);
    expect(
      V1CorrectGradeRequest.safeParse({
        ...review,
        reason: "Correction",
        draftId: id,
      }).success,
    ).toBe(false);
  });

  test("no caller-supplied storage path or provider URL is accepted", () => {
    for (
      const smuggled of [
        { privateScan: "papers/another-user/private.pdf" },
        { storage_path: "papers/another-user/private.pdf" },
        { attachment_path: "coach/another-user/private.pdf" },
        { providerUrl: "https://attacker.example/v1/complete" },
      ]
    ) {
      expect(V1ReviewGradeRequest.safeParse({ ...review, ...smuggled }).success)
        .toBe(false);
    }
  });

  test("the Study Coach upload purpose cannot be requested", () => {
    expect(V1UploadablePurpose.options).not.toContain("coach_attachment");
    expect(
      V1CreateUploadIntentRequest.safeParse({
        schoolId: id,
        purpose: "coach_attachment",
        displayName: "notes.pdf",
        expectedSizeBytes: 1024,
        declaredMediaType: "application/pdf",
        sha256: "a".repeat(64),
        studentId: id,
      }).success,
    ).toBe(false);
  });

  test("legacy coach_attachment objects stay describable in responses", () => {
    expect(
      V1File.safeParse({
        id,
        purpose: "coach_attachment",
        displayName: "legacy-file",
        sizeBytes: 1,
        declaredMediaType: "application/pdf",
        detectedMediaType: null,
        scanState: "quarantined",
        createdAt: "2026-09-18T00:00:00Z",
        scannedAt: null,
        failureCode: null,
      }).success,
    ).toBe(true);
  });
});

describe("AI-072 egress and credentials", () => {
  // The scanned trees are everything that can run on a server or ship in the
  // app. This file is excluded because it has to spell the names it forbids.
  const scanned = [
    "apps/api/src",
    "apps/worker/src",
    "packages/contracts/src",
    "packages/domain/src",
    "packages/infrastructure/src",
    "packages/observability/src",
    "supabase/functions",
    "lib",
  ];
  const forbidden = [
    /STUDY_COACH_(URL|KEY)/,
    /AI_GRADING_(URL|KEY)/,
    /AI_PROVIDER_API_KEY/,
    /functions\/v1\/(study-coach|propose-paper-grade)/,
    /['"](study-coach|propose-paper-grade)['"]/,
    /api\.openai\.com|api\.anthropic\.com|generativelanguage\.googleapis\.com/,
  ];

  async function sources(): Promise<Array<{ path: string; text: string }>> {
    const files: Array<{ path: string; text: string }> = [];
    for (const tree of scanned) {
      const glob = new Glob("**/*.{ts,dart}");
      for await (const path of glob.scan({ cwd: `${repoRoot}/${tree}` })) {
        const full = `${tree}/${path}`;
        files.push({
          path: full,
          text: await Bun.file(`${repoRoot}/${full}`).text(),
        });
      }
    }
    return files;
  }

  test("no runnable source reads an AI credential or calls an AI endpoint", async () => {
    const files = await sources();
    expect(files.length).toBeGreaterThan(100);
    const offenders = files.flatMap(({ path, text }) =>
      forbidden.filter((pattern) => pattern.test(text)).map((pattern) =>
        `${path}: ${pattern}`
      )
    );
    expect(offenders).toEqual([]);
  });

  test("no Edge Function forwards to an environment-selected URL", async () => {
    // study-coach's defect: fetch(Deno.env.get(...)). A changed variable must
    // never be able to retarget egress, so no function may fetch at all.
    const functions = (await sources()).filter(({ path }) =>
      path.startsWith("supabase/functions/")
    );
    expect(functions.length).toBeGreaterThan(0);
    for (const { path, text } of functions) {
      expect({ path, fetches: /\bfetch\s*\(/.test(text) }).toEqual({
        path,
        fetches: false,
      });
    }
  });

  test("neither env example declares an AI or Study Coach variable", async () => {
    for (const example of [".env.example", "supabase/functions/.env.example"]) {
      const text = await Bun.file(`${repoRoot}/${example}`).text();
      const declared = text.split("\n").filter((line) =>
        /^\s*#?\s*(STUDY_COACH|AI_GRADING|AI_PROVIDER)[A-Z_]*=/.test(line)
      );
      expect({ example, declared }).toEqual({ example, declared: [] });
    }
  });
});

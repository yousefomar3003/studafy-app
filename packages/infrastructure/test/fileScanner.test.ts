import { afterAll, describe, expect, test } from "bun:test";
import { EICAR_SIGNATURE } from "@studafy/domain";
import {
  ExternalMalwareScannerClient,
  FileSecurityScanner,
  LocalDeterministicScanner,
} from "../src/fileScanner";
import { sha256Hex } from "../src/privateFileStorage";

const PDF = new TextEncoder().encode(
  "%PDF-1.7\n1 0 obj\n<< /Type /Catalog >>\nendobj\n" +
    "trailer\n<< /Size 2 >>\nstartxref\n0\n%%EOF\n",
);
const EICAR = new TextEncoder().encode(EICAR_SIGNATURE);

type Behaviour =
  | "clean"
  | "malicious"
  | "500"
  | "malformed"
  | "redirect"
  | "hang";

let behaviour: Behaviour = "clean";
let calls = 0;
const provider = Bun.serve({
  port: 0,
  async fetch(request) {
    calls += 1;
    if (
      request.headers.get("authorization") !== "Bearer test-scanner-key-0001"
    ) {
      return new Response("no", { status: 401 });
    }
    await request.arrayBuffer();
    switch (behaviour) {
      case "clean":
        return Response.json({ clean: true });
      case "malicious":
        return Response.json({ clean: false });
      case "500":
        return new Response("oops", { status: 500 });
      case "malformed":
        return Response.json({ verdict: "probably fine" });
      case "redirect":
        return Response.redirect("https://example.invalid/", 302);
      case "hang":
        await Bun.sleep(1_000);
        return Response.json({ clean: true });
    }
  },
});
afterAll(() => provider.stop(true));

function scanner(timeoutMs = 2_000, apiKey = "test-scanner-key-0001") {
  return new FileSecurityScanner(
    new ExternalMalwareScannerClient({
      url: `http://127.0.0.1:${provider.port}/scan`,
      apiKey,
      timeoutMs,
    }),
  );
}

const input = (bytes: Uint8Array, mediaType = "application/pdf") => ({
  bytes,
  mediaType,
  purpose: "lesson_resource",
});

describe("FILE-051 local deterministic scanner", () => {
  test("clean carries the stored digest of the bytes to keep", async () => {
    const result = await new LocalDeterministicScanner().scan(input(PDF));
    expect(result.verdict).toBe("clean");
    expect(result.storedBytes).toBeNull();
    expect(result.storedSha256).toBe(await sha256Hex(PDF));
    expect(result.storedSizeBytes).toBe(PDF.byteLength);
    expect(result.scanPolicyVersion).toBe("file051-v1");
  });

  test("the EICAR test file is malicious and carries no stored bytes", async () => {
    const result = await new LocalDeterministicScanner().scan(input(EICAR));
    expect(result.verdict).toBe("malicious");
    expect(result.errorCode).toBe("malware_detected");
    expect(result.storedSha256).toBeNull();
    expect(result.storedBytes).toBeNull();
  });
});

describe("FILE-051 composed scanner never fails open", () => {
  test("provider clean + structural clean is clean", async () => {
    behaviour = "clean";
    expect((await scanner().scan(input(PDF))).verdict).toBe("clean");
  });

  test("provider malicious is terminal", async () => {
    behaviour = "malicious";
    const result = await scanner().scan(input(PDF));
    expect(result.verdict).toBe("malicious");
    expect(result.storedSha256).toBeNull();
  });

  test("structural rejection never consults the provider", async () => {
    behaviour = "clean";
    const before = calls;
    expect((await scanner().scan(input(EICAR))).verdict).toBe("malicious");
    expect(calls).toBe(before);
  });

  for (const failure of ["500", "malformed", "redirect", "hang"] as const) {
    test(`provider ${failure} is an infrastructure retry, never clean`, async () => {
      behaviour = failure;
      const result = await scanner(200).scan(input(PDF));
      expect(result.verdict).toBe("infrastructure");
      expect(result.storedSha256).toBeNull();
      expect(result.storedBytes).toBeNull();
    });
  }

  test("a rejected credential is an infrastructure retry", async () => {
    behaviour = "clean";
    const result = await scanner(2_000, "wrong-scanner-key-0000").scan(
      input(PDF),
    );
    expect(result.verdict).toBe("infrastructure");
  });

  test("an unreachable provider is an infrastructure retry", async () => {
    const offline = new FileSecurityScanner(
      new ExternalMalwareScannerClient({
        url: "http://127.0.0.1:9/scan",
        apiKey: "test-scanner-key-0001",
        timeoutMs: 500,
      }),
    );
    expect((await offline.scan(input(PDF))).verdict).toBe("infrastructure");
  });
});

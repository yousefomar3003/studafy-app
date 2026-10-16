import { describe, expect, test } from "bun:test";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { checkTarget, main, parseArgs } from "./clean-test-data.ts";

const A = "11111111-1111-4111-8111-111111111111";
const B = "22222222-2222-4222-8222-222222222222";

describe("clean-test-data arguments", () => {
  test("a dry run is the default; --execute needs exactly the schools named", () => {
    const dry = parseArgs(["--secrets", "f", "--schools", `${A},${B}`]);
    expect(dry.execute).toBe(false);
    expect(dry.schools).toEqual([A, B]);
    expect(() => parseArgs(["--secrets", "f", "--execute"])).toThrow(
      /--confirm-schools/,
    );
    expect(() =>
      parseArgs([
        "--secrets",
        "f",
        "--execute",
        "--schools",
        A,
        "--confirm-schools",
        B,
      ])
    ).toThrow(/different schools/);
    expect(() => parseArgs(["--secrets", "f", "--confirm-schools", A]))
      .toThrow(/is for --execute/);
    expect(
      parseArgs(["--secrets", "f", "--execute", "--confirm-schools", A])
        .schools,
    ).toEqual([A]);
    expect(() => parseArgs(["--secrets", "f", "--schools", "Test School"]))
      .toThrow(/not a school id/);
    expect(() => parseArgs(["--schools", A])).toThrow(/--secrets/);
  });

  test("the target: never the local development stack, only postgres, only a session connection", () => {
    expect(() =>
      checkTarget("postgresql://postgres:x@127.0.0.1:54322/postgres", true)
    ).toThrow(/local development/);
    expect(() =>
      checkTarget("postgresql://postgres:x@127.0.0.1:56922/postgres", false)
    ).toThrow(/--allow-local/);
    expect(() =>
      checkTarget(
        "postgresql://studafy_api_runtime.ref:x@aws-0-eu-central-1.pooler.supabase.com:5432/postgres",
        false,
      )
    ).toThrow(/must log in as postgres/);
    expect(() =>
      checkTarget(
        "postgresql://postgres.ref:x@aws-0-eu-central-1.pooler.supabase.com:6543/postgres",
        false,
      )
    ).toThrow(/session connection/);
    expect(() =>
      checkTarget(
        "postgresql://postgres.ref:x@aws-0-eu-central-1.pooler.supabase.com:5432/postgres",
        false,
      )
    ).not.toThrow();
  });

  test("refusals print no value from the secrets file", async () => {
    const dir = mkdtempSync(join(tmpdir(), "studafy-clean-args-"));
    try {
      const path = join(dir, "s.env");
      writeFileSync(
        path,
        "ADMIN_DATABASE_URL=postgresql://studafy_api_runtime.ref:SyntheticPw123@db.example:5432/postgres\n",
        { mode: 0o600 },
      );
      const lines: string[] = [];
      expect(await main(["--secrets", path], (line) => lines.push(line)))
        .toBe(64);
      expect(lines.join("\n")).toContain("must log in as postgres");
      expect(lines.join("\n")).not.toContain("SyntheticPw123");

      writeFileSync(
        path,
        "ADMIN_DATABASE_URL=postgresql://postgres.ref:SyntheticPw123@db.example:5432/postgres\n",
        { mode: 0o600 },
      );
      const executeLines: string[] = [];
      expect(
        await main(
          ["--secrets", path, "--execute", "--confirm-schools", A],
          (line) => executeLines.push(line),
        ),
      ).toBe(64);
      expect(executeLines.join("\n")).toContain("SUPABASE_SERVICE_ROLE_KEY");
      expect(executeLines.join("\n")).not.toContain("SyntheticPw123");
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
});

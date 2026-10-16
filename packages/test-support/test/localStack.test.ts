import { describe, expect, test } from "bun:test";
import { resolve } from "node:path";
import {
  inCi,
  parseStatusEnv,
  readLocalStack,
  stackApiUrl,
  stackFromStatus,
  StackTargetError,
  stackWorkdir,
  type StatusRunner,
} from "../src/localStack";

const STATUS = [
  "Stopped services: [supabase_studio_x]",
  'API_URL="http://127.0.0.1:56621"',
  'DB_URL="postgresql://postgres:postgres@127.0.0.1:56622/postgres"',
  'SERVICE_ROLE_KEY="synthetic-service"',
  'PUBLISHABLE_KEY="sb_publishable_synthetic"',
].join("\n");

describe("inCi", () => {
  test("is true only when CI is set to something truthy", () => {
    expect(inCi({ CI: "true" })).toBe(true);
    expect(inCi({ CI: "1" })).toBe(true);
    expect(inCi({})).toBe(false);
    expect(inCi({ CI: "" })).toBe(false);
    expect(inCi({ CI: "false" })).toBe(false);
    expect(inCi({ CI: "0" })).toBe(false);
  });
});

describe("stackWorkdir", () => {
  test("outside CI, an unnamed stack is refused", () => {
    expect(() => stackWorkdir("check", { env: {} })).toThrow(
      StackTargetError,
    );
    expect(() => stackWorkdir("check", { env: {} })).toThrow(
      /SUPABASE_WORKDIR/,
    );
  });

  test("in CI, the default stack is used", () => {
    expect(stackWorkdir("check", { env: { CI: "true" } })).toBeUndefined();
  });

  test("SUPABASE_WORKDIR names the stack, resolved to an absolute path", () => {
    expect(stackWorkdir("check", { env: { SUPABASE_WORKDIR: "a/b" } }))
      .toBe(resolve("a/b"));
  });

  test("a --workdir flag wins over SUPABASE_WORKDIR, in CI too", () => {
    expect(
      stackWorkdir("check", {
        env: { CI: "true", SUPABASE_WORKDIR: "/env" },
        workdir: "/flag",
      }),
    ).toBe("/flag");
  });
});

describe("stackApiUrl", () => {
  const defaultDb = "postgresql://postgres:postgres@127.0.0.1:54322/postgres";
  const otherDb = "postgresql://postgres:postgres@127.0.0.1:56622/postgres";

  test("the explicit variable always wins", () => {
    expect(
      stackApiUrl("X_URL", { X_URL: "http://127.0.0.1:56621" }),
    ).toBe("http://127.0.0.1:56621");
  });

  test("in CI, the default database implies the default API", () => {
    expect(stackApiUrl("X_URL", { CI: "true", DATABASE_URL: defaultDb }))
      .toBe("http://127.0.0.1:54321");
  });

  test("in CI, another database implies nothing", () => {
    expect(stackApiUrl("X_URL", { CI: "true", DATABASE_URL: otherDb }))
      .toBeUndefined();
  });

  test("outside CI, even the default database implies nothing", () => {
    expect(stackApiUrl("X_URL", { DATABASE_URL: defaultDb }))
      .toBeUndefined();
    expect(stackApiUrl("X_URL", {})).toBeUndefined();
  });

  test("an unparseable DATABASE_URL implies nothing", () => {
    expect(stackApiUrl("X_URL", { CI: "true", DATABASE_URL: "nonsense" }))
      .toBeUndefined();
  });
});

describe("parseStatusEnv and stackFromStatus", () => {
  test('only KEY="value" lines are read', () => {
    const values = parseStatusEnv(STATUS);
    expect(values.get("API_URL")).toBe("http://127.0.0.1:56621");
    expect(values.has("Stopped services")).toBe(false);
  });

  test("a report missing a value is refused", () => {
    expect(() => stackFromStatus("check", "/w", 'API_URL="http://127.0.0.1:1"'))
      .toThrow(/Is it running/);
  });

  test("a stack that is not on this machine is refused", () => {
    const hosted = STATUS.replace(
      "http://127.0.0.1:56621",
      "https://abc.supabase.co",
    );
    expect(() => stackFromStatus("check", "/w", hosted)).toThrow(
      /not on this machine/,
    );
  });
});

describe("readLocalStack", () => {
  const calls: string[][] = [];
  const run: StatusRunner = (args) => {
    calls.push(args);
    return { ok: true, stdout: STATUS };
  };

  test("asks the CLI about the named stack", () => {
    calls.length = 0;
    const stack = readLocalStack("check", {
      env: { SUPABASE_WORKDIR: "/tmp/guard" },
      run,
    });
    expect(calls).toEqual([
      ["status", "-o", "env", "--workdir", "/tmp/guard"],
    ]);
    expect(stack.apiUrl).toBe("http://127.0.0.1:56621");
    expect(stack.dbUrl).toContain(":56622/");
    expect(stack.serviceRoleKey).toBe("synthetic-service");
    expect(stack.values.get("PUBLISHABLE_KEY")).toBe(
      "sb_publishable_synthetic",
    );
  });

  test("in CI, asks about the default stack", () => {
    calls.length = 0;
    readLocalStack("check", { env: { CI: "true" }, run });
    expect(calls).toEqual([["status", "-o", "env"]]);
  });

  test("outside CI, never asks the CLI when no stack is named", () => {
    calls.length = 0;
    expect(() => readLocalStack("check", { env: {}, run })).toThrow(
      StackTargetError,
    );
    expect(calls).toEqual([]);
  });

  test("a stack that is not running is reported", () => {
    expect(() =>
      readLocalStack("check", {
        env: { SUPABASE_WORKDIR: "/tmp/guard" },
        run: () => ({ ok: false, stdout: "" }),
      })
    ).toThrow(/could not read the Supabase stack in \/tmp\/guard/);
  });
});

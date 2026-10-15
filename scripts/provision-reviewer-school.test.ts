import { describe, expect, test } from "bun:test";
import { mkdtempSync, readFileSync, statSync } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join, resolve } from "node:path";
import {
  ACCOUNTS,
  ANNOUNCEMENTS,
  checkMemberships,
  CLASSES,
  credentialsPath,
  DEFAULT_HOSTED_API_URL,
  EXAM,
  generatePassword,
  hostedConnection,
  isLoopback,
  localConnection,
  parseArgs,
  parseCredentials,
  passwordsFor,
  REVIEW_DOMAIN,
  REVIEW_SCHOOL_NAME,
  ROLES,
  writeCredentials,
} from "./provision-reviewer-school";

const REPO = resolve(import.meta.dir, "..");
const SECRET = "synthetic-service-role-value-that-must-never-print";

describe("command line", () => {
  test("local is the default and the credentials file is required", () => {
    expect(() => parseArgs([])).toThrow("--credentials-out is required");
    const options = parseArgs(["--credentials-out", "/tmp/x.json"]);
    expect(options.target).toBe("local");
    expect(options.rotate).toBe(false);
  });

  test("hosted only when asked, by name", () => {
    expect(
      parseArgs(["--target", "hosted", "--credentials-out", "/tmp/x.json"])
        .target,
    ).toBe("hosted");
    expect(() =>
      parseArgs(["--target", "prod", "--credentials-out", "/tmp/x.json"])
    ).toThrow("local or hosted");
    expect(() =>
      parseArgs(["--credentials-out", "/tmp/x.json", "--allow-production"])
    ).toThrow("only applies to --target hosted");
  });

  test("unknown flags and missing values are refused", () => {
    expect(() => parseArgs(["--credentials-out", "/tmp/x", "--reset"]))
      .toThrow("Unknown option --reset");
    expect(() => parseArgs(["--credentials-out", "--rotate"])).toThrow(
      "needs a value",
    );
  });
});

describe("the hosted connection", () => {
  const env = [
    "ENVIRONMENT=development",
    "SUPABASE_URL=https://abcdefghijklmnop.supabase.co",
    `SUPABASE_SERVICE_ROLE_KEY=${SECRET}`,
    `DATABASE_URL=postgres://postgres:${SECRET}@db.example/postgres`,
  ].join("\n");

  test("reads the URL and key, and defaults to the test copy's API", () => {
    const connection = hostedConnection(env, undefined, false);
    expect(connection.supabaseUrl).toBe(
      "https://abcdefghijklmnop.supabase.co",
    );
    expect(connection.serviceRoleKey).toBe(SECRET);
    expect(connection.apiUrl).toBe(DEFAULT_HOSTED_API_URL);
    expect(
      hostedConnection(
        `${env}\nREVIEWER_API_URL=https://api.example/`,
        undefined,
        false,
      ).apiUrl,
    ).toBe("https://api.example");
    expect(hostedConnection(env, "https://flag.example", false).apiUrl).toBe(
      "https://flag.example",
    );
  });

  test("errors name keys, never values", () => {
    const failures: string[] = [];
    for (
      const text of [
        `SUPABASE_URL=https://x.supabase.co`,
        `SUPABASE_SERVICE_ROLE_KEY=${SECRET}`,
        `SUPABASE_URL=http://${SECRET}.example\nSUPABASE_SERVICE_ROLE_KEY=${SECRET}`,
        `SUPABASE_URL=http://127.0.0.1:54321\nSUPABASE_SERVICE_ROLE_KEY=${SECRET}`,
        env.replace("ENVIRONMENT=development", "ENVIRONMENT=production"),
      ]
    ) {
      try {
        hostedConnection(text, undefined, false);
        failures.push("accepted");
      } catch (error) {
        failures.push((error as Error).message);
      }
    }
    expect(failures).not.toContain("accepted");
    for (const message of failures) expect(message).not.toContain(SECRET);
    expect(failures[0]).toContain("SUPABASE_SERVICE_ROLE_KEY");
    expect(failures[1]).toContain("SUPABASE_URL");
  });

  test("production needs --allow-production on top of --target hosted", () => {
    const production = env.replace(
      "ENVIRONMENT=development",
      "ENVIRONMENT=production",
    );
    expect(() => hostedConnection(production, undefined, false)).toThrow(
      "--allow-production",
    );
    expect(hostedConnection(production, undefined, true).target).toBe(
      "hosted",
    );
  });

  test("the API must be https and not this machine", () => {
    expect(() => hostedConnection(env, "http://api.example", false)).toThrow();
    expect(() => hostedConnection(env, "https://127.0.0.1:8080", false))
      .toThrow();
  });
});

describe("the local connection", () => {
  const status = [
    'API_URL="http://127.0.0.1:55921"',
    `SERVICE_ROLE_KEY="${SECRET}"`,
    'DB_URL="postgresql://postgres:postgres@127.0.0.1:55922/postgres"',
  ].join("\n");

  test("talks only to this machine", () => {
    const connection = localConnection(status, "http://127.0.0.1:55980/");
    expect(connection.target).toBe("local");
    expect(connection.apiUrl).toBe("http://127.0.0.1:55980");
    expect(() => localConnection(status, "https://studafy-api-test.fly.dev"))
      .toThrow("only talks to this machine");
    expect(() =>
      localConnection(
        status.replace("http://127.0.0.1:55921", "https://x.supabase.co"),
        undefined,
      )
    ).toThrow("only talks to this machine");
  });

  test("recognises loopback addresses only", () => {
    expect(isLoopback("http://localhost:1")).toBe(true);
    expect(isLoopback("http://[::1]:1")).toBe(true);
    expect(isLoopback("http://127.0.0.2:1")).toBe(false);
    expect(isLoopback("not a url")).toBe(false);
  });
});

describe("passwords and the credentials file", () => {
  test("passwords are long, varied and unique", () => {
    const seen = new Set<string>();
    for (let i = 0; i < 200; i += 1) {
      const password = generatePassword();
      expect(password).toMatch(
        /^[A-HJ-NP-Za-km-z2-9]{6}(-[A-HJ-NP-Za-km-z2-9]{6}){3}$/,
      );
      expect(password).toMatch(/[A-Z]/);
      expect(password).toMatch(/[a-z]/);
      expect(password).toMatch(/[2-9]/);
      seen.add(password);
    }
    expect(seen.size).toBe(200);
  });

  test("biased bytes are discarded rather than wrapped", () => {
    // 228 and above would favour the first letters; they must be skipped.
    let calls = 0;
    // 0 and 57 are both "A"; 30 is "g" and 50 is "3".
    const bytes = [255, 240, 228, 0, 57, 30, 50];
    const password = generatePassword((buffer) => {
      buffer[0] = bytes[calls % bytes.length]!;
      calls += 1;
      return buffer;
    });
    expect(password.startsWith("AAg3AA-")).toBe(true);
  });

  test("the file goes outside the repository", () => {
    expect(() => credentialsPath("reviewer.json", REPO)).toThrow(
      "outside the repository",
    );
    expect(() => credentialsPath(join(REPO, "docs", "x.json"), REPO)).toThrow();
    expect(credentialsPath("~/reviewer.json", REPO)).toBe(
      join(homedir(), "reviewer.json"),
    );
    expect(credentialsPath("/tmp/reviewer.json", REPO)).toBe(
      "/tmp/reviewer.json",
    );
  });

  test("it is written whole and readable by the owner only", () => {
    const dir = mkdtempSync(join(tmpdir(), "reviewer-"));
    const path = join(dir, "credentials.json");
    const file = {
      school: REVIEW_SCHOOL_NAME,
      target: "local" as const,
      apiUrl: "http://127.0.0.1:1",
      updatedAt: new Date().toISOString(),
      accounts: ROLES.map((role) => ({
        role,
        email: ACCOUNTS[role].email,
        password: generatePassword(),
      })),
    };
    writeCredentials(path, file);
    expect(statSync(path).mode & 0o777).toBe(0o600);
    expect(parseCredentials(readFileSync(path, "utf8"))).toEqual(file);
  });

  test("a re-run keeps the file's passwords; --rotate replaces them", () => {
    const existing = parseCredentials(JSON.stringify({
      accounts: ROLES.map((role) => ({
        role,
        email: ACCOUNTS[role].email,
        password: `kept-${role}-password-000`,
      })),
    }));
    let made = 0;
    const generate = () => `new-password-${(made += 1)}-0000000`;
    expect(passwordsFor(existing, false, generate).teacher).toBe(
      "kept-teacher-password-000",
    );
    const rotated = passwordsFor(existing, true, generate);
    expect(rotated.teacher).toStartWith("new-password-");
    expect(new Set(Object.values(rotated)).size).toBe(3);
    expect(passwordsFor(null, false, generate).parent).toStartWith("new-");
  });

  test("a file for other accounts is not taken for ours", () => {
    expect(() => parseCredentials("{}")).toThrow();
    expect(() =>
      parseCredentials(JSON.stringify({
        accounts: ROLES.map((role) => ({
          role,
          email: `${role}@example.com`,
          password: "long-enough-password-0",
        })),
      }))
    ).toThrow();
  });
});

describe("whose school it touches", () => {
  test("only the review school, and never as an administrator", () => {
    expect(() =>
      checkMemberships("teacher", [
        { schoolId: "a", schoolName: REVIEW_SCHOOL_NAME, role: "teacher" },
      ], null)
    ).not.toThrow();
    expect(() =>
      checkMemberships("teacher", [
        { schoolId: "b", schoolName: "Some Real School", role: "teacher" },
      ], null)
    ).toThrow("another school");
    expect(() =>
      checkMemberships("student", [
        { schoolId: "b", schoolName: REVIEW_SCHOOL_NAME, role: "student" },
      ], "a")
    ).toThrow("another school");
    expect(() =>
      checkMemberships("teacher", [
        { schoolId: "a", schoolName: REVIEW_SCHOOL_NAME, role: "school_admin" },
      ], "a")
    ).toThrow("administrator");
  });

  test("the accounts are a teacher, a student and a parent on Studafy's domain", () => {
    expect(ROLES).toEqual(["teacher", "student", "parent"]);
    for (const role of ROLES) {
      expect(ACCOUNTS[role].email).toBe(`${role}@${REVIEW_DOMAIN}`);
    }
    expect(REVIEW_DOMAIN).toBe("review.studafy.com");
  });

  test("the content covers every part a reviewer opens", () => {
    expect(CLASSES).toHaveLength(2);
    for (const plan of CLASSES) {
      expect(plan.lessons.length).toBeGreaterThan(0);
      expect(plan.homework.length).toBeGreaterThan(0);
    }
    expect(CLASSES.some((plan) => plan.homework.some((w) => w.handedIn)))
      .toBe(true);
    expect(EXAM.questions.map((q) => q.kind)).toEqual([
      "single_choice",
      "true_false",
      "short_answer",
      "essay",
    ]);
    expect(ANNOUNCEMENTS.length).toBeGreaterThan(0);
  });
});

/**
 * Provisions the app store reviewers' demo school (docs/store/reviewer-access.md).
 *
 * Google Play ("App access") and App Review need accounts that reach every
 * part of the app without a Google, Microsoft or Apple sign-in. This creates
 * a separate, wholly fictional school - "Cedar Grove Review School" - with a
 * teacher, a student and the student's parent, each signing in with an email
 * and a strong random password, and fills it with realistic work: two
 * classes, lessons, homework (one handed in), an open online exam, a
 * published grade and announcements. Reviewers never see anyone else's data:
 * the school is a teacher workspace of its own, and its only members are
 * these three accounts.
 *
 * Everything goes through the real /v1 API, as the three accounts - the same
 * commands the app sends - so nothing here can do what a teacher, student or
 * parent could not. The only service-role steps are Supabase Auth's: creating
 * the three accounts (each address first registered with
 * public.allow_provisioned_email_account, since email sign-up is otherwise
 * refused) and setting their passwords.
 *
 * Then, with the database connection, one more step no API can take: each
 * account is given its paid plans for a year without a purchase (comp
 * grants, docs/deployment/study-plans.md), so a reviewer reaches every paid
 * screen. The teacher and the student get Studafy Max; the parent gets
 * Studafy Max and Family+ for up to 8 children. A re-run adds nothing while a
 * grant has more than 30 days left, and renews one nearer its end.
 *
 * Safe to run again: it finds what exists and adds only what is missing.
 * Passwords live in the credentials file named on the command line, never on
 * screen. A re-run reuses the file's passwords (and puts them back if they
 * were changed); --rotate issues new ones.
 *
 * It refuses:
 *   - an existing account at a reviewer address that it did not create
 *     (no `studafy_reviewer` marker);
 *   - any reviewer account that belongs to a school other than the review
 *     school;
 *   - any target but this machine, unless `--target hosted` is given, which
 *     reads .env.hosted - SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY and, for
 *     the grants, DATABASE_URL as the database owner (values are never
 *     printed);
 *   - a production project, unless --allow-production is also given.
 *
 * Usage:
 *   # Local stack (default): Supabase from `supabase status`, API on loopback.
 *   # The stack is named with --workdir (or SUPABASE_WORKDIR); outside CI it
 *   # is never assumed (`--workdir .` means this checkout's own stack).
 *   bun --no-env-file scripts/provision-reviewer-school.ts \
 *     --credentials-out ~/studafy-reviewer-credentials.json \
 *     --api-url http://127.0.0.1:8080 --workdir <supabase workdir>
 *
 *   # Hosted test copy - only with the owner's go-ahead:
 *   bun --no-env-file scripts/provision-reviewer-school.ts --target hosted \
 *     --credentials-out ~/studafy-reviewer-credentials.json \
 *     [--api-url https://studafy-api-test.fly.dev] [--env-file .env.hosted]
 *
 *   Add --rotate to replace all three passwords.
 */
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, isAbsolute, relative, resolve } from "node:path";
import { parseEnv } from "node:util";
import postgres from "postgres";
import {
  databaseTls,
  usesTransactionPooler,
} from "../packages/database/src/index.ts";
import { stackWorkdir } from "../packages/test-support/src/localStack";

export const REVIEW_SCHOOL_NAME = "Cedar Grove Review School";
export const REVIEW_DOMAIN = "review.studafy.com";
/** Hosted test copy's API; the production API is passed with --api-url. */
export const DEFAULT_HOSTED_API_URL = "https://studafy-api-test.fly.dev";
const REPOSITORY_ROOT = resolve(import.meta.dir, "..");

export const ROLES = ["teacher", "student", "parent"] as const;
export type ReviewerRole = (typeof ROLES)[number];

export interface ReviewerAccount {
  role: ReviewerRole;
  email: string;
  displayName: string;
  gender: "male" | "female";
  kind: "adult" | "student";
}

/** Why each reviewer account holds its plans; the grants' `reason`. */
export const GRANT_REASON = "App store reviewer account";

/**
 * The paid plans each reviewer account is given without a purchase: every
 * account Studafy Max, and the parent Family+ for up to 8 children too.
 */
export const REVIEWER_GRANTS: Record<
  ReviewerRole,
  { studyPlan: "max"; familyPlus: "family_plus_large" | null }
> = {
  teacher: { studyPlan: "max", familyPlus: null },
  student: { studyPlan: "max", familyPlus: null },
  parent: { studyPlan: "max", familyPlus: "family_plus_large" },
};

export const ACCOUNTS: Record<ReviewerRole, ReviewerAccount> = {
  teacher: {
    role: "teacher",
    email: `teacher@${REVIEW_DOMAIN}`,
    displayName: "Nadia Haddad",
    gender: "female",
    kind: "adult",
  },
  student: {
    role: "student",
    email: `student@${REVIEW_DOMAIN}`,
    displayName: "Omar Saleh",
    gender: "male",
    kind: "student",
  },
  parent: {
    role: "parent",
    email: `parent@${REVIEW_DOMAIN}`,
    displayName: "Huda Saleh",
    gender: "female",
    kind: "adult",
  },
};

// ---------------------------------------------------------------------------
// Options and targets
// ---------------------------------------------------------------------------

export interface Options {
  target: "local" | "hosted";
  credentialsOut: string;
  apiUrl: string | undefined;
  workdir: string | undefined;
  envFile: string;
  rotate: boolean;
  allowProduction: boolean;
}

const USAGE = "Usage: bun --no-env-file scripts/provision-reviewer-school.ts " +
  "--credentials-out <file> [--target local|hosted] [--api-url <url>] " +
  "[--workdir <dir>] [--env-file <file>] [--rotate] [--allow-production]";

export function parseArgs(argv: readonly string[]): Options {
  const options: Options = {
    target: "local",
    credentialsOut: "",
    apiUrl: undefined,
    workdir: undefined,
    envFile: ".env.hosted",
    rotate: false,
    allowProduction: false,
  };
  for (let index = 0; index < argv.length; index += 1) {
    const flag = argv[index]!;
    const value = (): string => {
      const next = argv[index + 1];
      if (next === undefined || next.startsWith("--")) {
        throw new Error(`${flag} needs a value. ${USAGE}`);
      }
      index += 1;
      return next;
    };
    switch (flag) {
      case "--target": {
        const target = value();
        if (target !== "local" && target !== "hosted") {
          throw new Error(`--target is local or hosted, not "${target}".`);
        }
        options.target = target;
        break;
      }
      case "--credentials-out":
        options.credentialsOut = value();
        break;
      case "--api-url":
        options.apiUrl = value();
        break;
      case "--workdir":
        options.workdir = value();
        break;
      case "--env-file":
        options.envFile = value();
        break;
      case "--rotate":
        options.rotate = true;
        break;
      case "--allow-production":
        options.allowProduction = true;
        break;
      default:
        throw new Error(`Unknown option ${flag}. ${USAGE}`);
    }
  }
  if (!options.credentialsOut) {
    throw new Error(`--credentials-out is required. ${USAGE}`);
  }
  if (options.target === "local" && options.allowProduction) {
    throw new Error("--allow-production only applies to --target hosted.");
  }
  return options;
}

export interface Connection {
  target: "local" | "hosted";
  supabaseUrl: string;
  serviceRoleKey: string;
  apiUrl: string;
  /** For the plan grants only, which no API writes. */
  databaseUrl: string;
}

const LOOPBACK = new Set(["127.0.0.1", "localhost", "[::1]", "::1"]);

export function isLoopback(url: string): boolean {
  try {
    return LOOPBACK.has(new URL(url).hostname);
  } catch {
    return false;
  }
}

function withoutTrailingSlash(url: string): string {
  return url.replace(/\/+$/, "");
}

/**
 * The hosted connection from the text of .env.hosted. Only key names ever
 * appear in an error; values are never echoed, logged or returned to a
 * caller that prints them.
 */
export function hostedConnection(
  envText: string,
  apiUrlFlag: string | undefined,
  allowProduction: boolean,
): Connection {
  const env = parseEnv(envText) as Record<string, string | undefined>;
  const missing = ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "DATABASE_URL"]
    .filter((key) => !env[key]);
  if (missing.length > 0) {
    throw new Error(`The env file has no ${missing.join(" or ")}.`);
  }
  if ((env["ENVIRONMENT"] ?? "") === "production" && !allowProduction) {
    throw new Error(
      "The env file is for ENVIRONMENT=production. Re-run with " +
        "--allow-production only when the owner has approved provisioning " +
        "the reviewer school in production.",
    );
  }
  const supabaseUrl = withoutTrailingSlash(env["SUPABASE_URL"]!);
  let supabaseHost: string;
  try {
    const parsed = new URL(supabaseUrl);
    if (parsed.protocol !== "https:") throw new Error();
    supabaseHost = parsed.hostname;
  } catch {
    throw new Error("SUPABASE_URL in the env file is not an https URL.");
  }
  if (isLoopback(supabaseUrl)) {
    throw new Error("SUPABASE_URL in the env file points at this machine.");
  }
  const apiUrl = withoutTrailingSlash(
    apiUrlFlag ?? env["REVIEWER_API_URL"] ?? DEFAULT_HOSTED_API_URL,
  );
  if (!apiUrl.startsWith("https://") || isLoopback(apiUrl)) {
    throw new Error("The hosted API URL must be an https URL elsewhere.");
  }
  if (!supabaseHost) throw new Error("SUPABASE_URL has no host.");
  const databaseUrl = env["DATABASE_URL"]!;
  if (!isPostgresUrl(databaseUrl) || isLoopback(databaseUrl)) {
    throw new Error(
      "DATABASE_URL in the env file is not a postgres URL elsewhere.",
    );
  }
  return {
    target: "hosted",
    supabaseUrl,
    serviceRoleKey: env["SUPABASE_SERVICE_ROLE_KEY"]!,
    apiUrl,
    databaseUrl,
  };
}

function isPostgresUrl(url: string): boolean {
  try {
    return ["postgres:", "postgresql:"].includes(new URL(url).protocol);
  } catch {
    return false;
  }
}

/** The local connection from `supabase status -o env` output. */
export function localConnection(
  statusText: string,
  apiUrlFlag: string | undefined,
): Connection {
  const values = new Map<string, string>();
  for (const line of statusText.split("\n")) {
    const match = /^([A-Z_]+)="(.*)"$/.exec(line.trim());
    if (match?.[1] && match[2] !== undefined) values.set(match[1], match[2]);
  }
  const supabaseUrl = values.get("API_URL");
  const serviceRoleKey = values.get("SERVICE_ROLE_KEY");
  const databaseUrl = values.get("DB_URL");
  if (!supabaseUrl || !serviceRoleKey || !databaseUrl) {
    throw new Error(
      "The local stack did not report API_URL, SERVICE_ROLE_KEY and DB_URL.",
    );
  }
  const apiUrl = withoutTrailingSlash(apiUrlFlag ?? "http://127.0.0.1:8080");
  for (const url of [supabaseUrl, apiUrl, databaseUrl]) {
    if (!isLoopback(url)) {
      throw new Error(
        `Refusing ${new URL(url).host}: the local target only talks to ` +
          "this machine. Use --target hosted for the test copy.",
      );
    }
  }
  return {
    target: "local",
    supabaseUrl: withoutTrailingSlash(supabaseUrl),
    serviceRoleKey,
    apiUrl,
    databaseUrl,
  };
}

function connect(options: Options): Connection {
  if (options.target === "hosted") {
    const file = resolve(options.envFile);
    if (!existsSync(file)) throw new Error(`${options.envFile} not found.`);
    return hostedConnection(
      readFileSync(file, "utf8"),
      options.apiUrl,
      options.allowProduction,
    );
  }
  // Outside CI the stack is named (--workdir or SUPABASE_WORKDIR): the
  // default one is the developer's working stack.
  const workdir = stackWorkdir("Provisioning the review school locally", {
    workdir: options.workdir,
  });
  const status = spawnSync(
    "bunx",
    [
      "supabase",
      "status",
      "-o",
      "env",
      ...(workdir ? ["--workdir", workdir] : []),
    ],
    { encoding: "utf8" },
  );
  if (status.status !== 0) {
    throw new Error("Could not read the local stack (`supabase status`).");
  }
  return localConnection(status.stdout, options.apiUrl);
}

// ---------------------------------------------------------------------------
// Credentials
// ---------------------------------------------------------------------------

/** No 0/O, 1/l/I: reviewers may have to type it from a store console. */
const PASSWORD_ALPHABET =
  "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";

/**
 * Four groups of six from a 57-letter alphabet joined by hyphens: about
 * 140 bits, with upper and lower case, a digit and a symbol so any password
 * policy the project sets is met.
 */
export function generatePassword(
  random: (bytes: Uint8Array) => Uint8Array = (bytes) =>
    crypto.getRandomValues(bytes),
): string {
  for (;;) {
    const groups: string[] = [];
    for (let group = 0; group < 4; group += 1) {
      let text = "";
      while (text.length < 6) {
        const [byte] = random(new Uint8Array(1));
        // Rejection sampling keeps every letter equally likely.
        if (byte! < 228) text += PASSWORD_ALPHABET[byte! % 57];
      }
      groups.push(text);
    }
    const password = groups.join("-");
    if (
      /[A-Z]/.test(password) && /[a-z]/.test(password) &&
      /[2-9]/.test(password)
    ) {
      return password;
    }
  }
}

export interface CredentialsFile {
  school: string;
  target: "local" | "hosted";
  apiUrl: string;
  updatedAt: string;
  accounts: { role: ReviewerRole; email: string; password: string }[];
}

export function parseCredentials(text: string): CredentialsFile {
  const parsed = JSON.parse(text) as Partial<CredentialsFile>;
  const accounts = parsed.accounts;
  if (!Array.isArray(accounts)) throw new Error("no accounts");
  for (const role of ROLES) {
    const account = accounts.find((item) => item?.role === role);
    if (
      !account || account.email !== ACCOUNTS[role].email ||
      typeof account.password !== "string" || account.password.length < 16
    ) {
      throw new Error(`no usable ${role} entry`);
    }
  }
  return parsed as CredentialsFile;
}

/**
 * Where the credentials go: outside this repository, so they can never be
 * committed. `~` is expanded for convenience.
 */
export function credentialsPath(path: string, repositoryRoot: string): string {
  const expanded = path === "~" || path.startsWith("~/")
    ? resolve(homedir(), path.slice(2))
    : path;
  const absolute = resolve(expanded);
  const inside = relative(repositoryRoot, absolute);
  if (!inside.startsWith("..") && !isAbsolute(inside)) {
    throw new Error(
      "Write the credentials outside the repository (for example " +
        "~/studafy-reviewer-credentials.json), so they can never be committed.",
    );
  }
  return absolute;
}

/** Written whole, readable by the owner only. */
export function writeCredentials(path: string, file: CredentialsFile): void {
  const temporary = `${path}.tmp-${crypto.randomUUID()}`;
  writeFileSync(temporary, `${JSON.stringify(file, null, 2)}\n`, {
    mode: 0o600,
  });
  renameSync(temporary, path);
}

/** This run's passwords: the file's, unless rotating or there is none. */
export function passwordsFor(
  existing: CredentialsFile | null,
  rotate: boolean,
  generate: () => string = generatePassword,
): Record<ReviewerRole, string> {
  const result = {} as Record<ReviewerRole, string>;
  for (const role of ROLES) {
    const kept = existing?.accounts.find((item) => item.role === role);
    result[role] = !rotate && kept ? kept.password : generate();
  }
  return result;
}

// ---------------------------------------------------------------------------
// The school's content
// ---------------------------------------------------------------------------

export interface ClassPlan {
  key: "science" | "maths";
  name: string;
  grade: string;
  section: string;
  room: string;
  schedule: { weekday: number; startsAt: string; endsAt: string }[];
  lessons: { title: string; body: string }[];
  homework: {
    title: string;
    instructions: string;
    dueInDays: number;
    handedIn: string | null;
  }[];
}

export const CLASSES: ClassPlan[] = [
  {
    key: "science",
    name: "Grade 8 Science",
    grade: "8",
    section: "A",
    room: "Lab 2",
    schedule: [
      { weekday: 1, startsAt: "08:00", endsAt: "08:45" },
      { weekday: 3, startsAt: "08:00", endsAt: "08:45" },
    ],
    lessons: [
      {
        title: "Photosynthesis: how plants make their food",
        body:
          "Plants use sunlight, water and carbon dioxide to make glucose, " +
          "releasing oxygen. The green pigment chlorophyll, found in " +
          "chloroplasts, absorbs the light.\n\nWord equation: carbon dioxide " +
          "+ water -> glucose + oxygen (in the presence of light).\n\n" +
          "Key words: chlorophyll, chloroplast, stomata, glucose.",
      },
      {
        title: "The water cycle",
        body: "Water moves between the sea, the air and the land in a cycle: " +
          "evaporation, condensation, precipitation and collection. The sun " +
          "provides the energy that drives it.\n\nThink about: where does " +
          "the water in a puddle go on a hot day?",
      },
    ],
    homework: [
      {
        title: "Draw and label the water cycle",
        instructions:
          "Draw the water cycle on one page and label evaporation, " +
          "condensation, precipitation and collection. Add one sentence " +
          "for each stage explaining what happens.",
        dueInDays: 5,
        handedIn:
          "Evaporation: the sun heats water in the sea and it rises as " +
          "vapour. Condensation: the vapour cools and forms clouds. " +
          "Precipitation: water falls as rain. Collection: rain gathers in " +
          "rivers and flows back to the sea.",
      },
    ],
  },
  {
    key: "maths",
    name: "Grade 8 Mathematics",
    grade: "8",
    section: "A",
    room: "Room 14",
    schedule: [
      { weekday: 2, startsAt: "09:00", endsAt: "09:45" },
      { weekday: 4, startsAt: "09:00", endsAt: "09:45" },
    ],
    lessons: [
      {
        title: "Solving linear equations",
        body: "To solve an equation, do the same to both sides until the " +
          "unknown stands alone.\n\nExample: 3x + 5 = 20. Subtract 5: " +
          "3x = 15. Divide by 3: x = 5.\n\nAlways check by substituting " +
          "your answer back into the original equation.",
      },
      {
        title: "Ratios and proportion",
        body:
          "A ratio compares two quantities, such as 2 : 3. Two ratios are " +
          "in proportion when they simplify to the same ratio, as 4 : 6 " +
          "and 2 : 3 do.\n\nExample: a recipe for 4 people uses 300 g of " +
          "flour, so for 6 people it uses 450 g.",
      },
    ],
    homework: [
      {
        title: "Linear equations practice",
        instructions:
          "Solve and show your working:\n1. 2x + 7 = 19\n2. 5x - 4 = 21\n" +
          "3. 3(x + 2) = 24\n4. x / 4 + 3 = 8",
        dueInDays: 3,
        handedIn: null,
      },
    ],
  },
];

export const EXAM = {
  classKey: "science" as const,
  title: "Unit 2 quiz: Photosynthesis",
  category: "quiz",
  questions: [
    {
      position: 1,
      kind: "single_choice",
      prompt: "Which gas do plants take in for photosynthesis?",
      options: [
        { id: "a", text: "Oxygen" },
        { id: "b", text: "Carbon dioxide" },
        { id: "c", text: "Nitrogen" },
      ],
      correctOptionIds: ["b"],
      maximumScore: 2,
    },
    {
      position: 2,
      kind: "true_false",
      prompt: "Chlorophyll absorbs light energy.",
      correctChoice: true,
      maximumScore: 2,
    },
    {
      position: 3,
      kind: "short_answer",
      prompt: "Name the sugar that photosynthesis produces.",
      acceptedAnswers: ["glucose"],
      maximumScore: 2,
    },
    {
      position: 4,
      kind: "essay",
      prompt: "Explain why a plant kept in a dark cupboard for a week stops " +
        "growing.",
      maximumScore: 4,
    },
  ],
};

export const GRADED_TEST = {
  classKey: "maths" as const,
  title: "Unit 1 test: Integers",
  category: "test",
  maximumScore: 20,
  score: 17,
  feedback:
    "Strong work on negative numbers. Check the order of operations in " +
    "question 6.",
};

/** Class announcements: a teacher posts to a class, never school-wide. */
export const ANNOUNCEMENTS: {
  classKey: ClassPlan["key"];
  title: string;
  body: string;
  important: boolean;
}[] = [
  {
    classKey: "maths",
    title: "Welcome to the new term",
    body: "Welcome back to Grade 8 Mathematics! The timetable is in the app, " +
      "and homework is due on the day shown. Message me here if you have " +
      "any questions.",
    important: false,
  },
  {
    classKey: "science",
    title: "Botanical garden visit next Thursday",
    body: "Grade 8 Science will visit the botanical garden next Thursday. " +
      "Please bring a notebook, water and a hat. We return before lunch.",
    important: true,
  },
];

// ---------------------------------------------------------------------------
// Supabase Auth (service role) and the /v1 API
// ---------------------------------------------------------------------------

interface AuthUser {
  id: string;
  email?: string;
  app_metadata?: Record<string, unknown>;
}

class Auth {
  constructor(private readonly connection: Connection) {}

  private headers(): Record<string, string> {
    return {
      apikey: this.connection.serviceRoleKey,
      authorization: `Bearer ${this.connection.serviceRoleKey}`,
      "content-type": "application/json",
    };
  }

  private async call(
    method: string,
    path: string,
    body?: unknown,
  ): Promise<Response> {
    for (let attempt = 1;; attempt += 1) {
      const response = await fetch(`${this.connection.supabaseUrl}${path}`, {
        method,
        headers: this.headers(),
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
      // Supabase Auth answers 504 when it is slow; the call is safe to
      // repeat, since every step looks before it writes.
      if ((response.status === 504 || response.status === 429) && attempt < 4) {
        await Bun.sleep(attempt * 3000);
        continue;
      }
      return response;
    }
  }

  async findUser(email: string): Promise<AuthUser | null> {
    for (let page = 1; page <= 50; page += 1) {
      const response = await this.call(
        "GET",
        `/auth/v1/admin/users?page=${page}&per_page=1000`,
      );
      if (!response.ok) {
        throw new Error(`Listing accounts failed (${response.status}).`);
      }
      const body = await response.json() as { users?: AuthUser[] };
      const users = body.users ?? [];
      const found = users.find((user) => user.email?.toLowerCase() === email);
      if (found) return found;
      if (users.length < 1000) return null;
    }
    throw new Error("Too many accounts to search.");
  }

  async createUser(
    account: ReviewerAccount,
    password: string,
  ): Promise<string> {
    const allowed = await this.call(
      "POST",
      "/rest/v1/rpc/allow_provisioned_email_account",
      { requested_email: account.email },
    );
    if (!allowed.ok) {
      throw new Error(
        `Registering ${account.email} failed (${allowed.status}). Is ` +
          "migration 202610150050 applied?",
      );
    }
    const response = await this.call("POST", "/auth/v1/admin/users", {
      email: account.email,
      password,
      email_confirm: true,
      app_metadata: { studafy_reviewer: true },
      user_metadata: { full_name: account.displayName },
    });
    if (!response.ok) {
      throw new Error(`Creating ${account.email} failed (${response.status}).`);
    }
    return (await response.json() as { id: string }).id;
  }

  async setPassword(id: string, email: string, password: string) {
    const response = await this.call("PUT", `/auth/v1/admin/users/${id}`, {
      password,
    });
    if (!response.ok) {
      throw new Error(
        `Setting the password of ${email} failed (${response.status}).`,
      );
    }
  }

  /** Revokes every session of the token's account except this one. */
  async signOutOthers(accessToken: string): Promise<void> {
    const response = await fetch(
      `${this.connection.supabaseUrl}/auth/v1/logout?scope=others`,
      {
        method: "POST",
        headers: {
          apikey: this.connection.serviceRoleKey,
          authorization: `Bearer ${accessToken}`,
        },
      },
    );
    if (!response.ok) {
      throw new Error(`Ending old sessions failed (${response.status}).`);
    }
  }

  async signIn(email: string, password: string): Promise<string> {
    const response = await this.call(
      "POST",
      "/auth/v1/token?grant_type=password",
      { email, password },
    );
    if (!response.ok) {
      throw new Error(`Signing in as ${email} failed (${response.status}).`);
    }
    const body = await response.json() as { access_token?: string };
    if (!body.access_token) throw new Error(`No session for ${email}.`);
    return body.access_token;
  }
}

type Json = Record<string, unknown>;

class Api {
  constructor(
    private readonly baseUrl: string,
    private readonly tokens: Record<ReviewerRole, string>,
  ) {}

  async call<T = Json>(
    as: ReviewerRole,
    method: "GET" | "POST",
    path: string,
    body?: unknown,
  ): Promise<T> {
    const headers = new Headers({
      authorization: `Bearer ${this.tokens[as]}`,
      "content-type": "application/json",
    });
    if (method !== "GET") headers.set("idempotency-key", crypto.randomUUID());
    for (let attempt = 1;; attempt += 1) {
      const response = await fetch(`${this.baseUrl}${path}`, {
        method,
        headers,
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      });
      if (
        (response.status === 429 || response.status === 503 ||
          response.status === 504) && attempt < 4
      ) {
        await Bun.sleep(attempt * 3000);
        continue;
      }
      const parsed = await response.json().catch(() => ({})) as Json;
      if (!response.ok) {
        // Problem details carry a code and a request id, never a secret.
        throw new Error(
          `${method} ${path} as ${as} failed (${response.status} ${
            String(parsed["code"] ?? "")
          }, request ${String(parsed["requestId"] ?? "?")}).`,
        );
      }
      return parsed as T;
    }
  }
}

function items<T = Json>(page: Json): T[] {
  return (page["items"] as T[] | undefined) ?? [];
}

function daysFromNow(days: number, hour = 21): string {
  const date = new Date(Date.now() + days * 86_400_000);
  date.setUTCHours(hour, 0, 0, 0);
  return date.toISOString();
}

// ---------------------------------------------------------------------------
// Provisioning
// ---------------------------------------------------------------------------

function log(message: string): void {
  console.log(message);
}

/** Refuses accounts that belong anywhere but the review school. */
export function checkMemberships(
  role: ReviewerRole,
  memberships: { schoolId: string; schoolName: string; role: string }[],
  reviewSchoolId: string | null,
): void {
  for (const membership of memberships) {
    if (membership.role === "school_admin") {
      throw new Error(
        `The reviewer ${role} holds an administrator membership. Refusing.`,
      );
    }
    const ours = reviewSchoolId
      ? membership.schoolId === reviewSchoolId
      : membership.schoolName === REVIEW_SCHOOL_NAME;
    if (!ours) {
      throw new Error(
        `The reviewer ${role} belongs to another school ` +
          `(${membership.schoolId}). Refusing to touch it.`,
      );
    }
  }
}

async function ensureAccounts(
  auth: Auth,
  passwords: Record<ReviewerRole, string>,
): Promise<Record<ReviewerRole, string>> {
  const ids = {} as Record<ReviewerRole, string>;
  for (const role of ROLES) {
    const account = ACCOUNTS[role];
    const existing = await auth.findUser(account.email);
    if (existing) {
      if (existing.app_metadata?.["studafy_reviewer"] !== true) {
        throw new Error(
          `${account.email} exists but was not created by this script. ` +
            "Refusing to touch it.",
        );
      }
      await auth.setPassword(existing.id, account.email, passwords[role]);
      ids[role] = existing.id;
      log(`  ${role}: account exists; password set from the credentials.`);
    } else {
      ids[role] = await auth.createUser(account, passwords[role]);
      log(`  ${role}: account created.`);
    }
  }
  return ids;
}

/**
 * Gives each reviewer account its plans for a year (REVIEWER_GRANTS). Comp
 * grants are written only with direct database access - no API writes them
 * - exactly as docs/deployment/study-plans.md describes for an operator.
 * Idempotent: nothing is added while the account holds the same grant for
 * this reason with more than 30 days left; nearer its end a new year starts.
 */
export async function ensureGrants(
  sql: postgres.Sql,
  ids: Record<ReviewerRole, string>,
): Promise<void> {
  for (const role of ROLES) {
    const id = ids[role];
    const { studyPlan, familyPlus } = REVIEWER_GRANTS[role];
    const plan = await sql`
      insert into private.study_plan_grants (user_id, plan, reason, ends_at)
      select ${id}::uuid, ${studyPlan}, ${GRANT_REASON}, now() + interval '1 year'
      where not exists (
        select 1 from private.study_plan_grants g
        where g.user_id = ${id}::uuid and g.plan = ${studyPlan}
          and g.reason = ${GRANT_REASON}
          and g.starts_at <= now() and g.ends_at > now() + interval '30 days'
      )
    `;
    log(
      `  ${role}: Studafy ${studyPlan === "max" ? "Max" : "Plus"} ` +
        (plan.count > 0 ? "given for a year." : "already held."),
    );
    if (!familyPlus) continue;
    const family = await sql`
      insert into private.family_plus_grants (user_id, tier, reason, ends_at)
      select ${id}::uuid, ${familyPlus}, ${GRANT_REASON}, now() + interval '1 year'
      where not exists (
        select 1 from private.family_plus_grants g
        where g.user_id = ${id}::uuid and g.tier = ${familyPlus}
          and g.reason = ${GRANT_REASON}
          and g.starts_at <= now() and g.ends_at > now() + interval '30 days'
      )
    `;
    log(
      `  ${role}: Family+ (up to 8 children) ` +
        (family.count > 0 ? "given for a year." : "already held."),
    );
  }
}

async function grantPlans(
  connection: Connection,
  ids: Record<ReviewerRole, string>,
): Promise<void> {
  const ssl = databaseTls(connection.databaseUrl, process.env.DATABASE_CA_CERT);
  const sql = postgres(connection.databaseUrl, {
    ...(ssl === undefined ? {} : { ssl }),
    max: 1,
    connect_timeout: 20,
    prepare: !usesTransactionPooler(connection.databaseUrl),
    onnotice: () => {},
  });
  try {
    await sql.begin((tx) => ensureGrants(tx as unknown as postgres.Sql, ids));
  } catch (error) {
    // The driver's message names the table or the refusal, never the URL.
    const reason = error instanceof Error ? error.message : "unknown error";
    throw new Error(
      `Giving the reviewer plans failed (${reason}). DATABASE_URL must be ` +
        "the database owner, and migration 202610190010 applied.",
    );
  } finally {
    await sql.end({ timeout: 5 });
  }
}

async function provision(api: Api): Promise<{ schoolId: string }> {
  // Profiles: the kind of account and first-sign-in setup, so each door
  // opens straight onto its home screen.
  for (const role of ROLES) {
    const account = ACCOUNTS[role];
    await api.call(role, "POST", "/v1/account/profile", {
      displayName: account.displayName,
      gender: account.gender,
      locale: "en",
      completeSetup: true,
      accountKind: account.kind,
    });
  }

  // The school is the teacher's own workspace.
  const me = {} as Record<
    ReviewerRole,
    { memberships: { schoolId: string; schoolName: string; role: string }[] }
  >;
  for (const role of ROLES) me[role] = await api.call(role, "GET", "/v1/me");
  for (const role of ROLES) checkMemberships(role, me[role].memberships, null);
  let schoolId = me.teacher.memberships.find((m) => m.role === "teacher")
    ?.schoolId;
  if (!schoolId) {
    const workspace = await api.call(
      "teacher",
      "POST",
      "/v1/onboarding/teacher-workspace",
      {
        name: REVIEW_SCHOOL_NAME,
        timezone: "Asia/Amman",
        locale: "en",
      },
    );
    schoolId = workspace["id"] as string;
    log(`  school created: ${REVIEW_SCHOOL_NAME}.`);
  } else {
    log(`  school exists: ${REVIEW_SCHOOL_NAME}.`);
  }

  // Classes.
  const classIds = {} as Record<ClassPlan["key"], string>;
  const existingClasses = items<{ id: string; name: string }>(
    await api.call("teacher", "GET", `/v1/classrooms?schoolId=${schoolId}`),
  );
  for (const plan of CLASSES) {
    const found = existingClasses.find((item) => item.name === plan.name);
    if (found) {
      classIds[plan.key] = found.id;
      continue;
    }
    const created = await api.call("teacher", "POST", "/v1/classrooms", {
      schoolId,
      name: plan.name,
      grade: plan.grade,
      section: plan.section,
      room: plan.room,
      schedule: plan.schedule.map((slot) => ({
        ...slot,
        effectiveFrom: "2026-09-01",
        effectiveUntil: null,
      })),
    });
    classIds[plan.key] = created["id"] as string;
    log(`  class created: ${plan.name}.`);
  }

  // The student joins each class through a single-use join link, as a
  // real student would.
  let studentId: string | null = null;
  for (const plan of CLASSES) {
    const classroomId = classIds[plan.key];
    const roster = items<{ id: string; displayName: string }>(
      await api.call(
        "teacher",
        "GET",
        `/v1/classrooms/${classroomId}/students`,
      ),
    );
    let enrolled = roster.find((item) =>
      item.displayName === ACCOUNTS.student.displayName
    );
    if (!enrolled) {
      const link = await api.call(
        "teacher",
        "POST",
        `/v1/classrooms/${classroomId}/join-link`,
        {
          maxUses: 1,
          expiresAt: daysFromNow(1),
        },
      );
      await api.call("student", "POST", "/v1/class-join-links/redeem", {
        token: link["token"],
      });
      const after = items<{ id: string; displayName: string }>(
        await api.call(
          "teacher",
          "GET",
          `/v1/classrooms/${classroomId}/students`,
        ),
      );
      enrolled = after.find((item) =>
        item.displayName === ACCOUNTS.student.displayName
      );
      log(`  student joined ${plan.name}.`);
    }
    if (!enrolled) throw new Error(`The student is not in ${plan.name}.`);
    studentId = enrolled.id;
  }
  if (!studentId) throw new Error("The student has no student record.");

  // Every account now belongs to the review school only.
  for (const role of ROLES) {
    const current = await api.call<
      { memberships: { schoolId: string; schoolName: string; role: string }[] }
    >(role, "GET", "/v1/me");
    checkMemberships(role, current.memberships, schoolId);
  }

  // The parent asks to follow the student, and the student approves.
  const links = items<{ id: string; studentId: string; status: string }>(
    await api.call("parent", "GET", "/v1/me/guardian-links"),
  );
  let link = links.find((item) =>
    item.studentId === studentId &&
    (item.status === "verified" || item.status === "pending")
  );
  if (!link) {
    const requested = await api.call("parent", "POST", "/v1/guardian-links", {
      studentId,
      relationship: "parent",
    });
    link = {
      id: requested["id"] as string,
      studentId,
      status: requested["status"] as string,
    };
  }
  if (link.status === "pending") {
    await api.call(
      "student",
      "POST",
      `/v1/guardian-links/${link.id}/student-decision`,
      {
        decision: "approve",
      },
    );
    log("  parent linked to the student.");
  }

  // Lessons and homework.
  for (const plan of CLASSES) {
    const classroomId = classIds[plan.key];
    const resources = items<{ title: string }>(
      await api.call(
        "teacher",
        "GET",
        `/v1/resources?classroomId=${classroomId}`,
      ),
    );
    for (const lesson of plan.lessons) {
      if (resources.some((item) => item.title === lesson.title)) continue;
      const created = await api.call("teacher", "POST", "/v1/resources", {
        schoolId,
        classroomId,
        title: lesson.title,
        resourceType: "lesson_note",
        body: lesson.body,
        audience: "both",
      });
      if (created["state"] !== "published") {
        await api.call(
          "teacher",
          "POST",
          `/v1/resources/${created["id"]}/publish`,
          {
            expectedVersion: created["version"],
          },
        );
      }
      log(`  lesson added: ${lesson.title}.`);
    }

    const assignments = items<{ id: string; title: string }>(
      await api.call(
        "teacher",
        "GET",
        `/v1/assignments?classroomId=${classroomId}`,
      ),
    );
    for (const work of plan.homework) {
      let assignment = assignments.find((item) => item.title === work.title);
      if (!assignment) {
        const created = await api.call("teacher", "POST", "/v1/assignments", {
          classroomId,
          title: work.title,
          instructions: work.instructions,
          dueAt: daysFromNow(work.dueInDays),
          closesAt: null,
        });
        if (created["state"] !== "published") {
          await api.call(
            "teacher",
            "POST",
            `/v1/assignments/${created["id"]}/publish`,
            {
              expectedVersion: created["version"],
            },
          );
        }
        assignment = { id: created["id"] as string, title: work.title };
        log(`  homework set: ${work.title}.`);
      }
      if (work.handedIn) {
        const mine = items<{ id: string; submissionId: string | null }>(
          await api.call(
            "student",
            "GET",
            `/v1/assignments?classroomId=${classroomId}`,
          ),
        ).find((item) => item.id === assignment!.id);
        if (mine && !mine.submissionId) {
          await api.call(
            "student",
            "POST",
            `/v1/assignments/${assignment.id}/submit`,
            {
              answerText: work.handedIn,
            },
          );
          log(`  student handed in: ${work.title}.`);
        }
      }
    }
  }

  // The open online exam, left for the reviewer to take as the student.
  const examClass = classIds[EXAM.classKey];
  const assessments = items<{ title: string }>(
    await api.call(
      "teacher",
      "GET",
      `/v1/assessments?classroomId=${examClass}`,
    ),
  );
  if (!assessments.some((item) => item.title === EXAM.title)) {
    const created = await api.call("teacher", "POST", "/v1/assessments", {
      classroomId: examClass,
      title: EXAM.title,
      category: EXAM.category,
      maximumScore: EXAM.questions.reduce((sum, q) => sum + q.maximumScore, 0),
      scheduledAt: null,
      delivery: "online",
      questions: EXAM.questions.map((question) => ({
        preferredAnswer: null,
        ...question,
      })),
      opensAt: daysFromNow(-1, 6),
      closesAt: daysFromNow(21),
      maxAttempts: 2,
      attemptPolicy: "best",
      answerRelease: "after_close",
    });
    if (created["state"] !== "published") {
      await api.call(
        "teacher",
        "POST",
        `/v1/assessments/${created["id"]}/publish`,
        {
          expectedVersion: created["version"],
        },
      );
    }
    log(`  online exam published: ${EXAM.title}.`);
  }

  // A marked, published paper test, so grades show for student and parent.
  const testClass = classIds[GRADED_TEST.classKey];
  const testList = items<
    { id: string; title: string; state: string; version: number }
  >(
    await api.call(
      "teacher",
      "GET",
      `/v1/assessments?classroomId=${testClass}`,
    ),
  );
  let paper = testList.find((item) => item.title === GRADED_TEST.title);
  if (!paper) {
    const created = await api.call("teacher", "POST", "/v1/assessments", {
      classroomId: testClass,
      title: GRADED_TEST.title,
      category: GRADED_TEST.category,
      maximumScore: GRADED_TEST.maximumScore,
      scheduledAt: daysFromNow(-7, 7),
      delivery: "paper",
      questions: [],
    });
    paper = {
      id: created["id"] as string,
      title: GRADED_TEST.title,
      state: created["state"] as string,
      version: created["version"] as number,
    };
    log(`  paper test added: ${GRADED_TEST.title}.`);
  }
  if (paper.state !== "published") {
    await api.call("teacher", "POST", `/v1/assessments/${paper.id}/publish`, {
      expectedVersion: paper.version,
    });
  }
  const gradebook = await api.call<{
    item: { gradebookVersion: number };
    items: {
      student: { id: string };
      grade: { state: string; version: number } | null;
    }[];
  }>("teacher", "GET", `/v1/assessments/${paper.id}/gradebook`);
  const row = gradebook.items.find((item) => item.student.id === studentId);
  if (row && row.grade?.state !== "published") {
    const saved = await api.call<{ gradebookVersion: number }>(
      "teacher",
      "POST",
      `/v1/assessments/${paper.id}/grades/drafts`,
      {
        expectedGradebookVersion: gradebook.item.gradebookVersion,
        entries: [{
          studentId,
          expectedVersion: row.grade?.version ?? 0,
          mark: "scored",
          score: GRADED_TEST.score,
          feedback: GRADED_TEST.feedback,
        }],
      },
    );
    await api.call(
      "teacher",
      "POST",
      `/v1/assessments/${paper.id}/grades/publish`,
      {
        expectedGradebookVersion: saved.gradebookVersion,
      },
    );
    log(`  grade published: ${GRADED_TEST.score}/${GRADED_TEST.maximumScore}.`);
  }

  // Announcements.
  const announcements = items<{ title: string }>(
    await api.call("teacher", "GET", `/v1/announcements?schoolId=${schoolId}`),
  );
  for (const announcement of ANNOUNCEMENTS) {
    if (announcements.some((item) => item.title === announcement.title)) {
      continue;
    }
    await api.call("teacher", "POST", "/v1/announcements", {
      schoolId,
      classroomId: classIds[announcement.classKey],
      title: announcement.title,
      body: announcement.body,
      audience: "both",
      important: announcement.important,
    });
    log(`  announcement posted: ${announcement.title}.`);
  }

  return { schoolId };
}

export async function main(argv: readonly string[]): Promise<void> {
  const options = parseArgs(argv);
  const output = credentialsPath(options.credentialsOut, REPOSITORY_ROOT);
  if (!existsSync(dirname(output))) {
    throw new Error(`The folder for ${options.credentialsOut} does not exist.`);
  }
  const connection = connect(options);
  log(
    `Provisioning ${REVIEW_SCHOOL_NAME} on the ${connection.target} target ` +
      `(API ${connection.apiUrl}).`,
  );

  let existing: CredentialsFile | null = null;
  if (existsSync(output) && !options.rotate) {
    try {
      existing = parseCredentials(readFileSync(output, "utf8"));
    } catch (error) {
      throw new Error(
        `${options.credentialsOut} is not a credentials file this script ` +
          `wrote (${error instanceof Error ? error.message : "unreadable"}). ` +
          "Move it away, or pass --rotate to replace it.",
      );
    }
  }
  const passwords = passwordsFor(existing, options.rotate);
  // Written before any account changes, so a run that stops halfway never
  // leaves a password that exists only on the server.
  writeCredentials(output, {
    school: REVIEW_SCHOOL_NAME,
    target: connection.target,
    apiUrl: connection.apiUrl,
    updatedAt: new Date().toISOString(),
    accounts: ROLES.map((role) => ({
      role,
      email: ACCOUNTS[role].email,
      password: passwords[role],
    })),
  });
  if (!existing) {
    log(`New passwords written to ${options.credentialsOut} (mode 600).`);
  }

  const auth = new Auth(connection);
  log("Accounts:");
  const ids = await ensureAccounts(auth, passwords);

  const tokens = {} as Record<ReviewerRole, string>;
  for (const role of ROLES) {
    tokens[role] = await auth.signIn(ACCOUNTS[role].email, passwords[role]);
    // A rotation also ends every session signed in with an old password.
    if (options.rotate) await auth.signOutOthers(tokens[role]);
  }
  if (options.rotate) log("Other sessions of the three accounts ended.");
  log("Content:");
  const { schoolId } = await provision(new Api(connection.apiUrl, tokens));
  log("Plans:");
  await grantPlans(connection, ids);
  log(
    `Done. Review school ${schoolId}. Sign-in details are in ` +
      `${options.credentialsOut}; paste them into Play Console and App Store ` +
      "Connect as docs/store/reviewer-access.md describes.",
  );
}

if (import.meta.main) {
  main(Bun.argv.slice(2)).catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    process.exitCode = 1;
  });
}

/**
 * Reviews one safety report (DPIA D7; docs/security/safe043-operator-runbook.md,
 * "Reviewing a report"). For the platform operator who received a report
 * alert in Telegram. The app's Account, Safety reports is the normal path
 * (same commands, same audit); this script is the fallback.
 *
 *   bun --no-env-file scripts/review-report.ts show <reportId>
 *   bun --no-env-file scripts/review-report.ts resolve <reportId> \
 *     --resolution upheld|not_upheld|partial|no_action \
 *     --note "<what was decided and why>"
 *
 * Env (set explicitly; --no-env-file keeps the repository's .env out):
 *   REVIEW_DATABASE_URL  a session connection as postgres (direct, or the
 *                        session pooler on :5432), from the password manager
 *   OPERATOR_USER_ID     your own account id; it must be a platform operator
 *   DATABASE_CA_CERT     optional, the Supabase root CA
 *
 * It acts as you, inside the same SQL the API runs, and it can do no more
 * than the API would let you do:
 * - `show` calls private.report_review_open, which requires you to be a
 *   platform operator holding an *active* moderation grant (requested with
 *   MFA, approved by a second operator or, in single-reviewer mode, by you,
 *   started by you) whose scope covers
 *   this report. Every attempt is written to audit_events, refused ones too.
 *   Without a grant it prints the school id to request one for, and how:
 *   in single-reviewer mode (DL-063: the setting is on and you are the only
 *   platform operator) you approve your own grant, requested with
 *   requiresSecondApprover false; otherwise a second operator approves it.
 * - `resolve` sends the existing triageReport (when the report is still
 *   queued) and resolveReport commands through private.api042_command with
 *   an idempotency reservation, exactly as the API does. They check the
 *   grant again, write report_events and audit_events, and notify the
 *   reporter that the report was resolved.
 *
 * The connection itself is the trust boundary: whoever holds the postgres
 * password could bypass all of this. The script exists so the normal path
 * is the audited one.
 */
import postgres from "postgres";
import { databaseTls } from "../packages/database/src/index.ts";

type Sql = ReturnType<typeof postgres>;

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export class UsageError extends Error {
  constructor(message: string) {
    super(
      `${message}\nusage: review-report.ts show <reportId>\n` +
        "       review-report.ts resolve <reportId> --resolution upheld|not_upheld|partial|no_action --note <text>",
    );
    this.name = "UsageError";
  }
}

function usage(message = "unknown command"): never {
  throw new UsageError(message);
}

function option(args: string[], name: string): string | undefined {
  const at = args.indexOf(name);
  return at >= 0 ? args[at + 1] : undefined;
}

/** public.report_resolution, as resolveReport accepts it. */
export const RESOLUTIONS = [
  "upheld",
  "not_upheld",
  "partial",
  "no_action",
] as const;
export type Resolution = (typeof RESOLUTIONS)[number];

export interface ReviewArgs {
  command: "show" | "resolve";
  reportId: string;
  resolution?: Resolution;
  note?: string;
}

export function parseArgs(argv: string[]): ReviewArgs {
  const [command, reportId, ...rest] = argv;
  if (command !== "show" && command !== "resolve") usage();
  if (!reportId || !UUID.test(reportId)) usage("reportId must be a uuid");
  if (command === "show") return { command, reportId };
  const resolution = option(rest, "--resolution");
  if (!RESOLUTIONS.includes(resolution as Resolution)) {
    usage(`--resolution must be one of ${RESOLUTIONS.join(", ")}`);
  }
  const note = option(rest, "--note")?.trim();
  if (!note || note.length < 8 || note.length > 2000) {
    usage("--note is required: 8-2000 characters saying what was decided");
  }
  return { command, reportId, resolution: resolution as Resolution, note };
}

/** One transaction carrying the operator's identity, like the API's. */
async function asOperator<T>(
  sql: Sql,
  operator: string,
  schoolId: string | null,
  work: (tx: Sql) => Promise<T>,
): Promise<T> {
  return await sql.begin(async (tx) => {
    await tx.unsafe(
      `select set_config('request.jwt.claim.sub', $1, true),
              set_config('studafy.school_id', $2, true),
              set_config('studafy.request_id', $3, true)`,
      [operator, schoolId ?? "", `review-report-${crypto.randomUUID()}`],
    );
    return await work(tx as unknown as Sql);
  }) as T;
}

interface OpenResult {
  outcome: "ok" | "no_grant" | "forbidden" | "not_found";
  schoolId?: string;
  schoolHash?: string;
  report?: {
    id: string;
    schoolId: string;
    status: string;
    version: number;
    [key: string]: unknown;
  };
}

async function open(
  sql: Sql,
  operator: string,
  reportId: string,
): Promise<OpenResult> {
  const [row] = await asOperator(
    sql,
    operator,
    null,
    (tx) =>
      tx.unsafe(`select private.report_review_open($1::uuid) as r`, [
        reportId,
      ]),
  );
  return JSON.parse(JSON.stringify(row?.r)) as OpenResult;
}

const hex = (bytes: number) =>
  Array.from(crypto.getRandomValues(new Uint8Array(bytes)))
    .map((b) => b.toString(16).padStart(2, "0")).join("");

/** A command through the API's own dispatcher and idempotency gate. */
async function command(
  sql: Sql,
  operator: string,
  schoolId: string,
  operation: "triageReport" | "resolveReport",
  reportId: string,
  body: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const [reservation] = await asOperator(
    sql,
    operator,
    schoolId,
    (tx) =>
      tx.unsafe(
        `select private.api_idempotency_reserve($1::uuid, $2, $3, $4) as r`,
        [schoolId, `v1.${operation}`, `review-report.${hex(16)}`, hex(32)],
      ),
  );
  const reserved = JSON.parse(JSON.stringify(reservation?.r)) as {
    id?: string;
    generation?: number;
    outcome?: string;
  };
  if (!reserved.id) {
    throw new Error(`${operation}: reservation refused (${reserved.outcome})`);
  }
  const [row] = await asOperator(
    sql,
    operator,
    schoolId,
    (tx) =>
      tx.unsafe(
        `select private.api042_command($1, $2::uuid, $3::text::jsonb, $4::uuid, $5) as c`,
        [
          operation,
          reportId,
          // aal2 false: this script cannot prove a second factor. Triage and
          // resolve do not require one; grants (which do) go through the API.
          JSON.stringify({ responseStatus: 200, aal2: false, body }),
          reserved.id,
          reserved.generation ?? 1,
        ],
      ),
  );
  const result = JSON.parse(JSON.stringify(row?.c)) as {
    outcome: string;
    response?: Record<string, unknown>;
  };
  if (result.outcome !== "ok") {
    throw new Error(`${operation} refused: ${result.outcome}`);
  }
  return result.response ?? {};
}

/**
 * What to do without a grant. In single-reviewer mode (DL-063) the only
 * platform operator approves their own grant, which must be requested with
 * requiresSecondApprover false; otherwise a different operator approves it.
 */
export function noGrantHelp(
  result: Pick<OpenResult, "schoolId" | "schoolHash">,
  singleReviewer: boolean,
): string {
  const scope =
    '    resourceScope: {"reportIds": ["<reportId>"]}, durationMinutes: 60';
  return [
    "You hold no active moderation grant covering this report (the attempt is audited).",
    `School: ${result.schoolId} (alert hash #${result.schoolHash})`,
    ...(singleReviewer
      ? [
        "Single-reviewer mode is on (DL-063): you are the only platform operator.",
        "Request a grant with MFA, approve it yourself with MFA, then start it:",
        "  POST /internal/moderation/access  {schoolId, reason, ticketRef,",
        `${scope},`,
        "    requiresSecondApprover: false}",
        "  POST /internal/moderation/access/<grantId>/approve   (you)",
        "  POST /internal/moderation/access/<grantId>/start     (you)",
      ]
      : [
        "Request one with MFA, have a second operator approve it, then start it:",
        "  POST /internal/moderation/access  {schoolId, reason, ticketRef,",
        `${scope}}`,
        "  POST /internal/moderation/access/<grantId>/approve   (the other operator)",
        "  POST /internal/moderation/access/<grantId>/start     (you)",
      ]),
    "See docs/security/safe043-operator-runbook.md, Reviewing a report.",
  ].join("\n");
}

/** Whether single-reviewer mode applies now (202610160041). */
async function singleReviewerMode(sql: Sql): Promise<boolean> {
  const [row] = await sql.unsafe(
    `select private.safety_single_reviewer_mode() as single`,
  );
  return row?.["single"] === true;
}

function configuration(): {
  args: ReviewArgs;
  url: string;
  operator: string;
} {
  try {
    const args = parseArgs(process.argv.slice(2));
    const url = process.env.REVIEW_DATABASE_URL;
    const operator = process.env.OPERATOR_USER_ID ?? "";
    if (!url) usage("REVIEW_DATABASE_URL is required");
    if (!UUID.test(operator)) usage("OPERATOR_USER_ID must be your account id");
    return { args, url, operator };
  } catch (error) {
    if (!(error instanceof UsageError)) throw error;
    console.error(error.message);
    process.exit(64);
  }
}

if (import.meta.main) {
  const { args, url, operator } = configuration();

  const ssl = databaseTls(url, process.env.DATABASE_CA_CERT);
  const sql = postgres(url, {
    ...(ssl === undefined ? {} : { ssl }),
    max: 1,
    prepare: false,
    onnotice: () => {},
    connection: { application_name: "studafy-review-report" },
  });
  let exitCode = 0;
  try {
    const opened = await open(sql, operator, args.reportId);
    if (opened.outcome === "no_grant") {
      console.error(noGrantHelp(opened, await singleReviewerMode(sql)));
      exitCode = 2;
    } else if (opened.outcome !== "ok" || !opened.report) {
      console.error(
        opened.outcome === "forbidden"
          ? "OPERATOR_USER_ID is not a platform operator."
          : "No such report.",
      );
      exitCode = 1;
    } else if (args.command === "show") {
      console.log(JSON.stringify(opened.report, null, 2));
    } else {
      let { status, version } = opened.report;
      const schoolId = opened.report.schoolId;
      if (status === "submitted" || status === "queued") {
        const triaged = await command(
          sql,
          operator,
          schoolId,
          "triageReport",
          args.reportId,
          { expectedVersion: version, note: "Opened by review-report.ts" },
        );
        status = String(triaged.status);
        version = Number(triaged.version);
      }
      if (status !== "under_review" && status !== "on_hold") {
        throw new Error(`A ${status} report cannot be resolved.`);
      }
      const resolved = await command(
        sql,
        operator,
        schoolId,
        "resolveReport",
        args.reportId,
        {
          expectedVersion: version,
          resolution: args.resolution,
          note: args.note,
        },
      );
      console.log(JSON.stringify({
        reportId: args.reportId,
        status: resolved.status,
        resolution: resolved.resolution,
        version: resolved.version,
      }));
    }
  } catch (error) {
    // The message only: a refused command or a state the report is not in.
    console.error(error instanceof Error ? error.message : String(error));
    exitCode = 1;
  } finally {
    await sql.end({ timeout: 5 });
  }
  process.exit(exitCode);
}

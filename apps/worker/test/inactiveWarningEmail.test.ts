import { describe, expect, test } from "bun:test";
import type { Sql } from "@studafy/database";
import {
  ChannelSendError,
  type EmailMessage,
  type EmailSender,
  ResendEmailSender,
} from "@studafy/infrastructure";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import { sendInactiveWarningEmails } from "../src/processors/inactiveWarningEmail";
import { startRetentionSchedule } from "../src/processors/retentionSweep";

interface Job {
  userId: string;
  email: string | null;
  locale: string;
}

type Finish = [string, boolean, string | null, boolean, string | null];

/**
 * The database side as the claim/finish functions answer it. The claim
 * ignores email preferences by design (supabase/tests/
 * inactive_account_warning_email.sql); here a job is handed out once.
 */
function fakeDatabase(jobs: Job[], pending = jobs.length) {
  const finished: Finish[] = [];
  const queries: string[] = [];
  let claimed = false;
  const sql = ((strings: TemplateStringsArray, ...values: unknown[]) => {
    const text = strings.join("?");
    if (text.includes("inactive_warning_email_pending")) {
      queries.push("pending");
      return Promise.resolve([{ pending }]);
    }
    if (text.includes("inactive_warning_email_claim")) {
      queries.push("claim");
      const handed = claimed ? [] : jobs;
      claimed = true;
      return Promise.resolve([{ jobs: handed }]);
    }
    if (text.includes("inactive_warning_email_finish")) {
      queries.push("finish");
      const row = values as Finish;
      finished.push(row);
      const [, sent, , terminal] = row;
      return Promise.resolve([{
        outcome: sent ? "sent" : terminal ? "failed" : "retry",
      }]);
    }
    if (text.includes("counts")) {
      return Promise.resolve([{ counts: {} }]);
    }
    return Promise.reject(new Error(`unexpected query: ${text}`));
  }) as unknown as Sql;
  return { sql, finished, queries };
}

/** The worker's own Resend sender with only the network stubbed. */
function stubbedResend(respond: (body: Record<string, unknown>) => Response) {
  const sent: Record<string, unknown>[] = [];
  const sender = new ResendEmailSender({
    apiKey: "re_synthetic_key_not_real_0123456789",
    from: "Studafy <no-reply@example.test>",
    fetchImpl: (async (_url: string, init: RequestInit) => {
      const body = JSON.parse(String(init.body)) as Record<string, unknown>;
      sent.push(body);
      return respond(body);
    }) as never,
  });
  return { sender, sent };
}

function logs() {
  const collector = new LogCollector();
  return {
    collector,
    logger: createJsonLogger("worker", "test", "debug", collector.sink),
  };
}

const LONER = "f0570000-0000-4000-8000-000000000003";
const STUDENT = "f0570000-0000-4000-8000-000000000002";

describe("inactive-account warning email", () => {
  test("is sent through Resend to everyone due, email preferences or not", async () => {
    // The loner turned email off; the claim hands them over all the same.
    const { sql, finished } = fakeDatabase([
      { userId: LONER, email: "idle.loner@example.test", locale: "ar" },
      { userId: STUDENT, email: "idle.student@example.test", locale: "en" },
    ]);
    const { sender, sent } = stubbedResend(() =>
      new Response(JSON.stringify({ id: `resend-${sentCount()}` }), {
        status: 200,
      })
    );
    let count = 0;
    const sentCount = () => ++count;
    const { collector, logger } = logs();

    const counts = await sendInactiveWarningEmails(sql, sender, logger);

    expect(counts).toEqual({ sent: 2, retry: 0, failed: 0, unconfigured: 0 });
    expect(sent.map((body) => body.to)).toEqual([
      ["idle.loner@example.test"],
      ["idle.student@example.test"],
    ]);
    // Fixed copy in the person's language, and why it ignores preferences.
    expect(sent[0]?.subject).toBe("سيُحذف حسابك");
    expect(String(sent[0]?.text)).toContain("لم يُستخدم حسابك");
    expect(String(sent[0]?.text)).toContain("هذا إشعار ضروري");
    expect(sent[1]?.subject).toBe("Your account will be deleted");
    expect(String(sent[1]?.text)).toContain("required notice");
    // emailed_at is recorded with the provider's id.
    expect(finished).toEqual([
      [LONER, true, null, false, "resend-1"],
      [STUDENT, true, null, false, "resend-2"],
    ]);
    expect(
      collector.parsed().find((l) => l.event === "inactive_warning_emails"),
    )
      .toMatchObject({ sent: 2, retry: 0, failed: 0 });
    // Counts only: never an address or a person.
    const logged = collector.lines.join("\n");
    expect(logged).not.toContain("example.test");
    expect(logged).not.toContain(LONER);
  });

  test("a warning already emailed is not sent again", async () => {
    const { sql } = fakeDatabase([
      { userId: LONER, email: "idle.loner@example.test", locale: "en" },
    ]);
    const { sender, sent } = stubbedResend(() =>
      new Response(JSON.stringify({ id: "resend-1" }), { status: 200 })
    );
    const { logger } = logs();
    await sendInactiveWarningEmails(sql, sender, logger);
    const second = await sendInactiveWarningEmails(sql, sender, logger);
    expect(sent).toHaveLength(1);
    expect(second).toEqual({ sent: 0, retry: 0, failed: 0, unconfigured: 0 });
  });

  test("an outage is retried; a refused or missing address stops", async () => {
    const { sql, finished } = fakeDatabase([
      { userId: STUDENT, email: "down@example.test", locale: "en" },
      { userId: LONER, email: "bad@example.test", locale: "en" },
      {
        userId: "f0570000-0000-4000-8000-000000000006",
        email: null,
        locale: "en",
      },
    ]);
    const { sender, sent } = stubbedResend((body) =>
      new Response("{}", {
        status: (body.to as string[])[0] === "down@example.test" ? 503 : 422,
      })
    );
    const { logger } = logs();

    const counts = await sendInactiveWarningEmails(sql, sender, logger);

    expect(counts).toEqual({ sent: 0, retry: 1, failed: 2, unconfigured: 0 });
    expect(sent).toHaveLength(2); // nothing is sent without an address
    expect(finished.map(([, ok, code, terminal]) => [ok, code, terminal]))
      .toEqual([
        [false, "PROVIDER_UNAVAILABLE_503", false],
        [false, "EMAIL_ADDRESS_REJECTED", true],
        [false, "NO_ADDRESS", true],
      ]);
  });

  test("an unexpected sender error is a bounded, retryable code", async () => {
    const { sql, finished } = fakeDatabase([
      { userId: LONER, email: "idle.loner@example.test", locale: "en" },
    ]);
    const sender: EmailSender = {
      send: (_message: EmailMessage) =>
        Promise.reject(new Error("socket hang up idle.loner@example.test")),
    };
    const { collector, logger } = logs();
    await sendInactiveWarningEmails(sql, sender, logger);
    expect(finished[0]).toEqual([LONER, false, "SENDER_ERROR", false, null]);
    expect(collector.lines.join("\n")).not.toContain("example.test");
  });

  test("a ChannelSendError keeps its own code and terminality", async () => {
    const { sql, finished } = fakeDatabase([
      { userId: LONER, email: "idle.loner@example.test", locale: "en" },
    ]);
    const sender: EmailSender = {
      send: () =>
        Promise.reject(new ChannelSendError("PROVIDER_AUTH_401", false)),
    };
    const { logger } = logs();
    await sendInactiveWarningEmails(sql, sender, logger);
    expect(finished[0]).toEqual([
      LONER,
      false,
      "PROVIDER_AUTH_401",
      false,
      null,
    ]);
  });

  test("without an email provider it logs what waits, claims nothing and does not fail", async () => {
    const { sql, queries, finished } = fakeDatabase([
      { userId: LONER, email: "idle.loner@example.test", locale: "en" },
    ], 3);
    const { collector, logger } = logs();

    const counts = await sendInactiveWarningEmails(sql, undefined, logger);

    expect(counts).toEqual({ sent: 0, retry: 0, failed: 0, unconfigured: 3 });
    expect(queries).toEqual(["pending"]);
    expect(finished).toEqual([]);
    const line = collector.parsed().find((l) =>
      l.event === "inactive_warning_email_unconfigured"
    );
    expect(line).toMatchObject({ pending: 3, level: "warn" });
  });

  test("the retention pass sends them after the purges, and survives no provider", async () => {
    const { sql, queries } = fakeDatabase([], 2);
    const { collector, logger } = logs();
    const runtime = startRetentionSchedule(sql, logger, 3_600_000);
    const report = await runtime.runOnce();
    await runtime.close();
    expect(report.inactive_warning_emails).toEqual({
      sent: 0,
      retry: 0,
      failed: 0,
      unconfigured: 2,
    });
    expect(queries).toContain("pending");
    expect(collector.events()).not.toContain("retention_step_failed");
  });
});

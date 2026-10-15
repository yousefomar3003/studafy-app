import { describe, expect, test } from "bun:test";
import { ResendEmailSender } from "../packages/infrastructure/src/notifications/channelSenders.ts";
import { recipientFrom, sendTestEmail, TEST_EMAIL } from "./send-test-email";

const KEY = "re_synthetic_key_not_real_0123456789";
const FROM = "Studafy <no-reply@example.test>";
const TO = "owner@example.test";
const env = { RESEND_API_KEY: KEY, EMAIL_FROM_ADDRESS: FROM };

/** The worker's sender with only the network stubbed. */
function stubbedResend(respond: () => Response) {
  const calls: { url: string; init: RequestInit }[] = [];
  const makeSender = (config: { apiKey: string; from: string }) =>
    new ResendEmailSender({
      ...config,
      fetchImpl: (async (url: string, init: RequestInit) => {
        calls.push({ url, init });
        return respond();
      }) as never,
    });
  return { calls, makeSender };
}

function expectNoSecrets(line: string) {
  expect(line).not.toContain(KEY);
  expect(line).not.toContain("no-reply@example.test");
  expect(line).not.toContain(TO);
}

describe("send-test-email", () => {
  test("sends one email through Resend and prints only the message id", async () => {
    const { calls, makeSender } = stubbedResend(() =>
      new Response(JSON.stringify({ id: "email-123" }), { status: 200 })
    );

    const result = await sendTestEmail([TO], env, makeSender);

    expect(result).toEqual({ ok: true, line: "sent email-123" });
    expect(calls).toHaveLength(1);
    expect(calls[0]?.url).toBe("https://api.resend.com/emails");
    const headers = calls[0]?.init.headers as Record<string, string>;
    expect(headers.authorization).toBe(`Bearer ${KEY}`);
    expect(JSON.parse(String(calls[0]?.init.body))).toEqual({
      from: FROM,
      to: [TO],
      subject: TEST_EMAIL.subject,
      text: TEST_EMAIL.text,
    });
    expectNoSecrets(result.line);
  });

  test("accepts --to as well as a bare address", () => {
    expect(recipientFrom(["--to", TO])).toBe(TO);
    expect(recipientFrom([TO])).toBe(TO);
    expect(recipientFrom([])).toBeNull();
    expect(recipientFrom(["--to"])).toBeNull();
    expect(recipientFrom(["not-an-address"])).toBeNull();
    expect(recipientFrom(["a@b.c, d@e.f"])).toBeNull();
  });

  test("a provider refusal prints its code, never the key or addresses", async () => {
    const { makeSender } = stubbedResend(() =>
      new Response(JSON.stringify({ message: `bad key ${KEY}` }), {
        status: 401,
      })
    );
    const result = await sendTestEmail([TO], env, makeSender);
    expect(result).toEqual({ ok: false, line: "error PROVIDER_AUTH_401" });
    expectNoSecrets(result.line);
  });

  test("an unexpected failure is reduced to one code", async () => {
    const result = await sendTestEmail([TO], env, () => ({
      send: () => Promise.reject(new Error(`boom ${KEY} ${TO}`)),
    }));
    expect(result).toEqual({ ok: false, line: "error SENDER_ERROR" });
  });

  test("nothing is sent without configuration or a recipient", async () => {
    const { calls, makeSender } = stubbedResend(() =>
      new Response("{}", { status: 200 })
    );
    expect(await sendTestEmail([TO], {}, makeSender)).toEqual({
      ok: false,
      line: "error EMAIL_NOT_CONFIGURED",
    });
    expect(
      await sendTestEmail([TO], { RESEND_API_KEY: KEY }, makeSender),
    ).toEqual({ ok: false, line: "error EMAIL_NOT_CONFIGURED" });
    expect(await sendTestEmail([], env, makeSender)).toEqual({
      ok: false,
      line: "error RECIPIENT_REQUIRED",
    });
    expect(calls).toHaveLength(0);
  });

  test("the command prints one line and exits non-zero on error", () => {
    // Exercises the CLI entry point without any network: no recipient, so
    // it stops before a request (the key is synthetic either way).
    const run = Bun.spawnSync({
      cmd: [
        process.execPath,
        "--no-env-file",
        `${import.meta.dir}/send-test-email.ts`,
      ],
      env: { PATH: process.env.PATH ?? "", ...env },
      stdout: "pipe",
      stderr: "pipe",
    });
    const out = run.stdout.toString();
    expect(out).toBe("error RECIPIENT_REQUIRED\n");
    expect(run.exitCode).toBe(1);
    expectNoSecrets(out + run.stderr.toString());
  }, 30_000);
});

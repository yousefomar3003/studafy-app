/**
 * Sends one test email through the worker's email path (DL-053): the same
 * `ResendEmailSender`, configured from the same `RESEND_API_KEY` and
 * `EMAIL_FROM_ADDRESS`, so a pass here means the worker's email channel can
 * send.
 *
 *   RESEND_API_KEY=… EMAIL_FROM_ADDRESS=… \
 *     bun --no-env-file scripts/send-test-email.ts <address>
 *
 * Reads the key and the sender only from the environment. Prints one line:
 * `sent <provider message id>`, or `error <code>`. Never prints the key, the
 * sender or the address.
 */
// The sender module itself, not the package index, so the command does not
// load every other adapter (googleapis, pdf, Redis) just to send one email.
import {
  ChannelSendError,
  type EmailSender,
  ResendEmailSender,
} from "../packages/infrastructure/src/notifications/channelSenders.ts";

/** The fixed, content-free copy of the test email. */
export const TEST_EMAIL = {
  subject: "Test email",
  text:
    "Email from Studafy is working.\n\nThis is a test sent by the Studafy team; there is nothing to do.",
};

export interface TestEmailResult {
  ok: boolean;
  /** The single line printed: `sent <id>` or `error <code>`. */
  line: string;
}

// Deliberately loose: Resend validates the address; this only catches a
// missing or obviously mistyped argument before a request is made.
const ADDRESS = /^[^\s@<>,;]+@[^\s@<>,;]+\.[^\s@<>,;]+$/;

/** The recipient from `<address>` or `--to <address>`. */
export function recipientFrom(args: readonly string[]): string | null {
  const flag = args.indexOf("--to");
  const value = flag >= 0
    ? args[flag + 1]
    : args.find((arg) => !arg.startsWith("-"));
  return value && ADDRESS.test(value) ? value : null;
}

export async function sendTestEmail(
  args: readonly string[],
  env: Record<string, string | undefined>,
  makeSender: (config: { apiKey: string; from: string }) => EmailSender = (
    config,
  ) => new ResendEmailSender(config),
): Promise<TestEmailResult> {
  const to = recipientFrom(args);
  if (!to) return { ok: false, line: "error RECIPIENT_REQUIRED" };
  const apiKey = env.RESEND_API_KEY;
  const from = env.EMAIL_FROM_ADDRESS;
  if (!apiKey || !from) {
    return { ok: false, line: "error EMAIL_NOT_CONFIGURED" };
  }
  try {
    const sent = await makeSender({ apiKey, from }).send({
      to,
      subject: TEST_EMAIL.subject,
      text: TEST_EMAIL.text,
    });
    return { ok: true, line: `sent ${sent.providerMessageId ?? "unknown"}` };
  } catch (error) {
    // ChannelSendError codes are bounded (PROVIDER_AUTH_401, …); anything
    // else may carry provider text, so it is reduced to one code.
    const code = error instanceof ChannelSendError
      ? error.code
      : "SENDER_ERROR";
    return { ok: false, line: `error ${code}` };
  }
}

if (import.meta.main) {
  const result = await sendTestEmail(Bun.argv.slice(2), process.env);
  console.log(result.line);
  process.exit(result.ok ? 0 : 1);
}

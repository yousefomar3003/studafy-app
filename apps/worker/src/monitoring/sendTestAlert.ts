/**
 * Sends a test alert to the Telegram chat queue alerts go to (launch plan
 * 4.7, docs/deployment/queue-alerts.md).
 *
 *   bun run alerts:test
 *
 * Needs TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID, the same values the worker
 * uses. On the deployed worker:
 *
 *   fly ssh console -a studafy-worker-test -C "bun apps/worker/src/monitoring/sendTestAlert.ts"
 *
 * Prints the outcome only, never the token.
 */
import { TelegramAlertSender } from "@studafy/infrastructure";

export function testAlertText(environment: string, at: Date): string {
  return `TEST Studafy ${environment}: queue alerts reach this chat (${at.toISOString()}). Nothing is wrong.`;
}

if (import.meta.main) {
  const botToken = process.env.TELEGRAM_BOT_TOKEN;
  const chatId = process.env.TELEGRAM_CHAT_ID;
  if (!botToken || !chatId) {
    console.error(
      "alerts:test needs TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID in the environment",
    );
    process.exit(2);
  }
  const environment = process.env.ENVIRONMENT ?? "local";
  try {
    await new TelegramAlertSender({ botToken, chatId }).send(
      testAlertText(environment, new Date()),
    );
    console.log(`alerts:test sent to chat ${chatId} (${environment})`);
  } catch (error) {
    console.error(
      `alerts:test failed: ${
        error instanceof Error ? error.message : "unknown"
      }`,
    );
    process.exit(1);
  }
}

import { describe, expect, test } from "bun:test";
import { AlertSendError, TelegramAlertSender } from "../src/alerts/telegram";

const TOKEN = "123456:secret-bot-token-for-tests";

describe("Telegram alerts", () => {
  test("posts plain text to the chat, without link previews", async () => {
    const calls: { url: string; body: Record<string, unknown> }[] = [];
    const sender = new TelegramAlertSender({
      botToken: TOKEN,
      chatId: "-1001234",
      fetchImpl: ((url: string, init: RequestInit) => {
        calls.push({ url, body: JSON.parse(String(init.body)) });
        return Promise.resolve(new Response("{}", { status: 200 }));
      }) as typeof fetch,
    });
    await sender.send(
      "ALERT Studafy test: notifications queue: 600 jobs waiting",
    );
    expect(calls).toEqual([{
      url: `https://api.telegram.org/bot${TOKEN}/sendMessage`,
      body: {
        chat_id: "-1001234",
        text: "ALERT Studafy test: notifications queue: 600 jobs waiting",
        disable_web_page_preview: true,
      },
    }]);
  });

  test("a refusal or an unreachable API fails without revealing the token", async () => {
    const refused = new TelegramAlertSender({
      botToken: TOKEN,
      chatId: "1",
      fetchImpl: (() =>
        Promise.resolve(
          new Response("", { status: 401 }),
        )) as unknown as typeof fetch,
    });
    const unreachable = new TelegramAlertSender({
      botToken: TOKEN,
      chatId: "1",
      fetchImpl: (() =>
        Promise.reject(
          new TypeError(`fetch failed for ${TOKEN}`),
        )) as unknown as typeof fetch,
    });
    for (
      const [sender, code] of [[refused, "TELEGRAM_REFUSED_401"], [
        unreachable,
        "TELEGRAM_UNREACHABLE",
      ]] as const
    ) {
      const error = await sender.send("x").catch((e: unknown) => e);
      expect(error).toBeInstanceOf(AlertSendError);
      expect((error as Error).message).toBe(code);
      expect(String(error)).not.toContain("secret-bot-token");
    }
  });
});

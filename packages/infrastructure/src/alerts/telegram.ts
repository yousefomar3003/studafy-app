// Operator alerts to a Telegram chat (launch plan 4.7). The same bot the
// alert relay uses (ops/alert-relay) can be reused; alerts carry counts and
// queue names only, never a person's data.

export interface AlertSender {
  send(text: string): Promise<void>;
}

export class AlertSendError extends Error {
  constructor(readonly code: string) {
    // Never the URL: it contains the bot token.
    super(code);
    this.name = "AlertSendError";
  }
}

export interface TelegramConfig {
  botToken: string;
  chatId: string;
  fetchImpl?: typeof fetch;
}

/** Telegram's Bot API sendMessage, plain text. */
export class TelegramAlertSender implements AlertSender {
  readonly #config: TelegramConfig;

  constructor(config: TelegramConfig) {
    this.#config = config;
  }

  async send(text: string): Promise<void> {
    const fetchImpl = this.#config.fetchImpl ?? fetch;
    let response: Response;
    try {
      response = await fetchImpl(
        `https://api.telegram.org/bot${this.#config.botToken}/sendMessage`,
        {
          method: "POST",
          redirect: "error",
          signal: AbortSignal.timeout(10_000),
          headers: { "content-type": "application/json" },
          body: JSON.stringify({
            chat_id: this.#config.chatId,
            // Telegram's limit is 4096 characters.
            text: text.slice(0, 4000),
            disable_web_page_preview: true,
          }),
        },
      );
    } catch {
      throw new AlertSendError("TELEGRAM_UNREACHABLE");
    }
    if (!response.ok) {
      throw new AlertSendError(`TELEGRAM_REFUSED_${response.status}`);
    }
  }
}

import { describe, expect, test } from "bun:test";
import {
  type Alert,
  axiomAlert,
  checkUptime,
  type Env,
  handleRequest,
  type KeyValue,
  sameSecret,
  sentryAlert,
  telegramText,
} from "../src/index";

class MemoryState implements KeyValue {
  values = new Map<string, string>();
  get(key: string) {
    return Promise.resolve(this.values.get(key) ?? null);
  }
  put(key: string, value: string) {
    this.values.set(key, value);
    return Promise.resolve();
  }
  delete(key: string) {
    this.values.delete(key);
    return Promise.resolve();
  }
}

const env = (overrides: Partial<Env> = {}): Env => ({
  RELAY_SECRET: "s3cret-path-segment",
  TELEGRAM_BOT_TOKEN: "synthetic",
  TELEGRAM_CHAT_ID: "1",
  ...overrides,
});

describe("alerts become Telegram messages", () => {
  test("a Sentry issue alert", () => {
    const alert = sentryAlert({
      action: "triggered",
      data: {
        event: {
          title: "TypeError: cannot read 'id'",
          culprit: "apps/api/src/academic/routes.ts",
          web_url: "https://studafy.sentry.io/issues/1/",
        },
      },
    });
    expect(alert).toEqual({
      source: "Sentry",
      kind: "problem",
      title: "TypeError: cannot read 'id'",
      detail: "apps/api/src/academic/routes.ts",
      link: "https://studafy.sentry.io/issues/1/",
    });
    expect(telegramText(alert)).toBe(
      "🚨 Problem · Sentry\nTypeError: cannot read 'id'\n" +
        "apps/api/src/academic/routes.ts\nhttps://studafy.sentry.io/issues/1/",
    );
  });

  test("an Axiom monitor opening and closing", () => {
    expect(
      axiomAlert({
        action: "Open",
        event: { title: "API server errors", description: "6 in 5 min" },
      }),
    ).toEqual({
      source: "Axiom",
      kind: "problem",
      title: "API server errors",
      detail: "6 in 5 min",
      link: undefined,
    });
    expect(axiomAlert({ action: "Closed", event: { title: "x" } }).kind).toBe(
      "resolved",
    );
  });

  test("anything unexpected still produces a readable alert", () => {
    expect(sentryAlert({}).title).toBe("Sentry alert");
    expect(axiomAlert("nonsense").title).toBe("Axiom monitor");
  });
});

describe("the webhook endpoint", () => {
  const sent: Alert[] = [];
  const send = (_env: Env, alert: Alert) => {
    sent.push(alert);
    return Promise.resolve();
  };
  const post = (path: string, body: unknown) =>
    new Request(`https://relay.example${path}`, {
      method: "POST",
      body: JSON.stringify(body),
    });

  test("forwards only with the right secret", async () => {
    sent.length = 0;
    const ok = await handleRequest(
      post("/axiom/s3cret-path-segment", { event: { title: "t" } }),
      env(),
      send,
    );
    expect(ok.status).toBe(200);
    expect(sent).toHaveLength(1);

    for (
      const path of ["/axiom/wrong", "/axiom", "/other/s3cret-path-segment"]
    ) {
      const refused = await handleRequest(post(path, {}), env(), send);
      expect(refused.status).toBe(404);
    }
    expect(sent).toHaveLength(1);
  });

  test("a failed delivery asks the sender to retry", async () => {
    const response = await handleRequest(
      post("/sentry/s3cret-path-segment", {}),
      env(),
      () => Promise.reject(new Error("telegram down")),
    );
    expect(response.status).toBe(502);
  });

  test("secrets compare exactly", () => {
    expect(sameSecret("abc", "abc")).toBe(true);
    expect(sameSecret("abd", "abc")).toBe(false);
    expect(sameSecret("", "")).toBe(false);
  });
});

describe("uptime", () => {
  const run = (state: MemoryState, healthy: boolean[], at: string) => {
    const notified: Alert[] = [];
    let call = 0;
    return checkUptime(
      env({ UPTIME_URL: "https://api/readyz", STATE: state }),
      {
        probe: () => Promise.resolve(healthy[call++] ?? true),
        notify: (_env, alert) => {
          notified.push(alert);
          return Promise.resolve();
        },
        wait: () => Promise.resolve(),
        now: () => new Date(at),
      },
    ).then((result) => ({ result, notified }));
  };

  test("one failed try is not an outage", async () => {
    const state = new MemoryState();
    const { result, notified } = await run(
      state,
      [false, true],
      "2026-10-02T10:00:00Z",
    );
    expect(result).toBe("up");
    expect(notified).toHaveLength(0);
  });

  test("an outage alerts once when it starts and once when it ends", async () => {
    const state = new MemoryState();
    const first = await run(state, [false, false], "2026-10-02T10:00:00Z");
    expect(first.result).toBe("down");
    expect(first.notified.map((a) => a.kind)).toEqual(["problem"]);

    const still = await run(state, [false, false], "2026-10-02T10:01:00Z");
    expect(still.notified).toHaveLength(0);

    const back = await run(state, [true], "2026-10-02T10:07:00Z");
    expect(back.result).toBe("up");
    expect(back.notified.map((a) => a.kind)).toEqual(["resolved"]);
    expect(back.notified[0]!.detail).toBe("Down for about 7 minutes.");
  });

  test("nothing to check without a URL and state", async () => {
    expect(await checkUptime(env())).toBe("skipped");
  });
});

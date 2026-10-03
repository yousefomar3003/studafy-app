/**
 * Studafy alert relay (ADR-0035): a Cloudflare Worker, free tier.
 *
 * Neither Sentry nor Axiom can post to Telegram, so both send their alert
 * webhooks here and this forwards them to the team's Telegram chat. It also
 * checks the API's /readyz every minute, from outside Fly, so "the API is
 * down" is noticed even when nothing inside can report it - that alert goes
 * to Telegram and, through Resend, to email.
 *
 * Routes (the secret path segment keeps strangers from posting alerts):
 *   POST /sentry/<RELAY_SECRET>   Sentry alert webhook
 *   POST /axiom/<RELAY_SECRET>    Axiom monitor webhook
 *   GET  /health                  the relay itself
 *
 * Alerts carry titles and links only. Sentry and Axiom already strip
 * personal data; nothing here adds any.
 */

export interface KeyValue {
  get(key: string): Promise<string | null>;
  put(key: string, value: string): Promise<void>;
  delete(key: string): Promise<void>;
}

export interface Env {
  RELAY_SECRET: string;
  TELEGRAM_BOT_TOKEN: string;
  TELEGRAM_CHAT_ID: string;
  /** e.g. https://api.studafy.com/readyz */
  UPTIME_URL?: string;
  /** Email for uptime alerts (Sentry and Axiom email on their own). */
  RESEND_API_KEY?: string;
  ALERT_EMAIL_TO?: string;
  ALERT_EMAIL_FROM?: string;
  /** Remembers whether the API was down, so each outage alerts once. */
  STATE?: KeyValue;
}

export interface Alert {
  title: string;
  detail?: string;
  link?: string;
  /** "problem" opens, "resolved" closes. */
  kind: "problem" | "resolved";
  source: "Sentry" | "Axiom" | "Uptime";
}

const text = (value: unknown): string | undefined =>
  typeof value === "string" && value.trim() ? value.trim() : undefined;

const record = (value: unknown): Record<string, unknown> =>
  value && typeof value === "object" ? value as Record<string, unknown> : {};

/** Sentry's alert webhooks (issue alerts, metric alerts, legacy plugin). */
export function sentryAlert(body: unknown): Alert {
  const root = record(body);
  const data = record(root["data"]);
  const event = record(data["event"]);
  const issue = record(data["issue"]);
  const metric = record(data["metric_alert"]);
  const title = text(event["title"]) ?? text(issue["title"]) ??
    text(metric["title"]) ?? text(data["description_title"]) ??
    text(root["message"]) ?? "Sentry alert";
  const resolved = root["action"] === "resolved" ||
    text(data["description_text"])?.toLowerCase().includes("resolved") ===
      true;
  return {
    source: "Sentry",
    kind: resolved ? "resolved" : "problem",
    title,
    detail: text(event["culprit"]) ?? text(root["culprit"]) ??
      text(data["description_text"]),
    link: text(event["web_url"]) ?? text(issue["web_url"]) ??
      text(data["web_url"]) ?? text(root["url"]),
  };
}

/**
 * Strips Slack's mrkdwn link and emphasis syntax: `<url|label>` becomes the
 * label, `*bold*` and `_italic_` lose their markers.
 */
function plain(value: string): string {
  return value
    .replace(/<([^|>]+)\|([^>]+)>/g, "$2")
    .replace(/<([^>]+)>/g, "$1")
    .replace(/[*_~`]/g, "")
    .trim();
}

/**
 * Axiom's monitor alerts. Two shapes arrive here:
 *
 * - its webhook notifier: `{ action: "open" | "closed", event: {...} }`;
 * - its Slack notifier pointed at this relay (Axiom's free plan has Slack
 *   but no webhooks): Slack's incoming-webhook payload, `{ text,
 *   attachments: [{ title, title_link, text }], blocks }`.
 */
export function axiomAlert(body: unknown): Alert {
  const root = record(body);
  const event = record(root["event"]);
  const attachment = record(
    Array.isArray(root["attachments"]) ? root["attachments"][0] : undefined,
  );
  const blocks = Array.isArray(root["blocks"]) ? root["blocks"] : [];
  const blockText = blocks
    .map((block) => text(record(record(block)["text"])["text"]))
    .filter((line): line is string => Boolean(line))
    .map(plain);
  const slackText = text(root["text"])
    ? plain(String(root["text"]))
    : undefined;

  const action = String(root["action"] ?? event["action"] ?? "").toLowerCase();
  const title = text(event["title"]) ?? text(root["title"]) ??
    text(event["monitorName"]) ??
    (text(attachment["title"])
      ? plain(String(attachment["title"]))
      : undefined) ??
    blockText[0] ?? slackText?.split("\n")[0] ?? "Axiom monitor";
  const slackDetail = blockText.slice(1).join("\n") ||
    slackText?.split("\n").slice(1).join("\n") || undefined;
  const detail = text(event["description"]) ?? text(root["description"]) ??
    (event["value"] !== undefined ? `value: ${event["value"]}` : undefined) ??
    (text(attachment["text"])
      ? plain(String(attachment["text"]))
      : undefined) ??
    slackDetail;
  const everything = [action, title, detail ?? "", slackText ?? ""].join(" ")
    .toLowerCase();
  const resolved = action === "closed" || action === "resolved" ||
    (!action &&
      /\b(resolved|recovered|closed|back to normal)\b/.test(everything));
  return {
    source: "Axiom",
    kind: resolved ? "resolved" : "problem",
    title,
    detail: detail || undefined,
    link: text(event["url"]) ?? text(root["url"]) ??
      text(attachment["title_link"]),
  };
}

/** The Telegram message for an alert: plain text, so nothing is parsed. */
export function telegramText(alert: Alert): string {
  const mark = alert.kind === "resolved" ? "✅ Resolved" : "🚨 Problem";
  return [
    `${mark} · ${alert.source}`,
    alert.title,
    alert.detail,
    alert.link,
  ].filter((line): line is string => Boolean(line)).map((line) =>
    line.slice(0, 900)
  ).join("\n");
}

async function sendTelegram(env: Env, alert: Alert): Promise<void> {
  const response = await fetch(
    `https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`,
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        chat_id: env.TELEGRAM_CHAT_ID,
        text: telegramText(alert),
        disable_web_page_preview: true,
      }),
    },
  );
  if (!response.ok) throw new Error(`telegram ${response.status}`);
}

async function sendEmail(env: Env, alert: Alert): Promise<void> {
  if (!env.RESEND_API_KEY || !env.ALERT_EMAIL_TO || !env.ALERT_EMAIL_FROM) {
    return;
  }
  await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      authorization: `Bearer ${env.RESEND_API_KEY}`,
      "content-type": "application/json",
    },
    body: JSON.stringify({
      from: env.ALERT_EMAIL_FROM,
      to: [env.ALERT_EMAIL_TO],
      subject: `[Studafy] ${
        alert.kind === "resolved" ? "Resolved" : "Down"
      }: ${alert.title}`,
      text: telegramText(alert),
    }),
  });
}

/** Constant-time comparison, so the secret cannot be guessed by timing. */
export function sameSecret(given: string, expected: string): boolean {
  if (!expected || given.length !== expected.length) return false;
  let difference = 0;
  for (let i = 0; i < given.length; i++) {
    difference |= given.charCodeAt(i) ^ expected.charCodeAt(i);
  }
  return difference === 0;
}

export async function handleRequest(
  request: Request,
  env: Env,
  send: (env: Env, alert: Alert) => Promise<void> = sendTelegram,
): Promise<Response> {
  const url = new URL(request.url);
  const [, source, secret = ""] = url.pathname.split("/");
  if (request.method === "GET" && source === "health") {
    return new Response("ok");
  }
  if (
    request.method !== "POST" ||
    (source !== "sentry" && source !== "axiom") ||
    !sameSecret(secret, env.RELAY_SECRET)
  ) {
    return new Response("not found", { status: 404 });
  }
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return new Response("bad request", { status: 400 });
  }
  const alert = source === "sentry" ? sentryAlert(body) : axiomAlert(body);
  try {
    await send(env, alert);
  } catch {
    // Sentry and Axiom retry a failed webhook; tell them to.
    return new Response("delivery failed", { status: 502 });
  }
  return new Response("sent");
}

const DOWN_KEY = "api_down_since";

/**
 * One uptime check: two tries ten seconds apart, so a single slow response
 * is not an outage. Alerts only when the state changes - down once, back
 * up once - and remembers the state between runs.
 */
export async function checkUptime(
  env: Env,
  deps: {
    probe?: (url: string) => Promise<boolean>;
    notify?: (env: Env, alert: Alert) => Promise<void>;
    wait?: (ms: number) => Promise<void>;
    now?: () => Date;
  } = {},
): Promise<"up" | "down" | "skipped"> {
  if (!env.UPTIME_URL || !env.STATE) return "skipped";
  const probe = deps.probe ?? (async (url: string) => {
    try {
      const response = await fetch(url, {
        signal: AbortSignal.timeout(8_000),
      });
      return response.ok;
    } catch {
      return false;
    }
  });
  const notify = deps.notify ?? (async (e: Env, alert: Alert) => {
    await Promise.allSettled([sendTelegram(e, alert), sendEmail(e, alert)]);
  });
  const wait = deps.wait ??
    ((ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms)));
  const now = deps.now ?? (() => new Date());

  let healthy = await probe(env.UPTIME_URL);
  if (!healthy) {
    await wait(10_000);
    healthy = await probe(env.UPTIME_URL);
  }
  const downSince = await env.STATE.get(DOWN_KEY);

  if (!healthy && !downSince) {
    await env.STATE.put(DOWN_KEY, now().toISOString());
    await notify(env, {
      source: "Uptime",
      kind: "problem",
      title: "The Studafy API is not answering",
      detail: `${env.UPTIME_URL} failed twice, 10 seconds apart.`,
    });
  } else if (healthy && downSince) {
    await env.STATE.delete(DOWN_KEY);
    const minutes = Math.max(
      1,
      Math.round((now().getTime() - Date.parse(downSince)) / 60_000),
    );
    await notify(env, {
      source: "Uptime",
      kind: "resolved",
      title: "The Studafy API is answering again",
      detail: `Down for about ${minutes} minute${minutes === 1 ? "" : "s"}.`,
    });
  }
  return healthy ? "up" : "down";
}

export default {
  fetch: (request: Request, env: Env) => handleRequest(request, env),
  scheduled: (
    _event: unknown,
    env: Env,
    context: { waitUntil(promise: Promise<unknown>): void },
  ) => {
    context.waitUntil(checkUptime(env));
  },
};

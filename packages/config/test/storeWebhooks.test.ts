import { describe, expect, test } from "bun:test";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import {
  APP_STORE_NOTIFICATIONS_PATH,
  PLAY_BILLING_PUBSUB_TOPIC_ID,
  PLAY_BILLING_PUSH_PATH,
  pubSubAudienceMatchesPushPath,
} from "../src/index";

const root = resolve(import.meta.dir, "..", "..", "..");
const read = (path: string) => readFileSync(join(root, path), "utf8");

/** The documents an operator follows to set up store notifications. */
function setupDocs(): string[] {
  const docs = ["docs/deployment/subscriptions.md", ".env.example"];
  const ownerGuides = join(root, "docs", "guides", "owner");
  if (existsSync(ownerGuides)) {
    for (const file of readdirSync(ownerGuides)) {
      if (file.endsWith(".md")) docs.push(`docs/guides/owner/${file}`);
    }
  }
  return docs;
}

describe("store notification names (docs and code agree)", () => {
  test("the documented values", () => {
    expect(PLAY_BILLING_PUBSUB_TOPIC_ID).toBe("play-billing");
    expect(PLAY_BILLING_PUSH_PATH).toBe("/webhooks/google");
    expect(APP_STORE_NOTIFICATIONS_PATH).toBe("/webhooks/apple");
  });

  test("the subscriptions setup names the topic and both endpoints", () => {
    const doc = read("docs/deployment/subscriptions.md");
    expect(doc).toContain(`topics/${PLAY_BILLING_PUBSUB_TOPIC_ID}`);
    expect(doc).toContain(`https://<api-host>${PLAY_BILLING_PUSH_PATH}`);
    expect(doc).toContain(APP_STORE_NOTIFICATIONS_PATH);
  });

  test("every topic and webhook path in the setup docs is the one in code", () => {
    const paths = new Set([
      APP_STORE_NOTIFICATIONS_PATH,
      PLAY_BILLING_PUSH_PATH,
    ]);
    for (const doc of setupDocs()) {
      const text = read(doc);
      for (const [, topic] of text.matchAll(/topics\/([A-Za-z0-9._-]+)/g)) {
        expect(`${doc}: ${topic}`).toBe(
          `${doc}: ${PLAY_BILLING_PUBSUB_TOPIC_ID}`,
        );
      }
      for (const [path] of text.matchAll(/\/webhooks\/[A-Za-z0-9_-]+/g)) {
        expect(paths.has(path) ? path : `${doc}: ${path}`).toBe(path);
      }
    }
  });

  test("the owner guide uses the same names, once it is on this branch", () => {
    const guide = "docs/guides/owner/05-play-billing.md";
    if (!existsSync(join(root, guide))) return;
    const text = read(guide);
    expect(text).toContain(`\`${PLAY_BILLING_PUBSUB_TOPIC_ID}\``);
    expect(text).toContain(PLAY_BILLING_PUSH_PATH);
  });

  test("the example audience is a URL for the push endpoint", () => {
    const line = read(".env.example").split("\n").find((entry) =>
      /^#?\s*GOOGLE_PUBSUB_AUDIENCE=/.test(entry)
    );
    expect(line).toBeDefined();
    const value = line!.replace(/^#?\s*GOOGLE_PUBSUB_AUDIENCE=/, "").trim();
    expect(pubSubAudienceMatchesPushPath(value)).toBe(true);
  });

  test("an audience for another path is reported, not silently accepted", () => {
    expect(pubSubAudienceMatchesPushPath(undefined)).toBeNull();
    expect(
      pubSubAudienceMatchesPushPath(
        "https://studafy-api-test.fly.dev/webhooks/google",
      ),
    ).toBe(true);
    for (
      const wrong of [
        "https://studafy-api-test.fly.dev",
        "https://studafy-api-test.fly.dev/",
        "https://studafy-api-test.fly.dev/webhooks/google/",
        "https://studafy-api-test.fly.dev/webhooks/play",
        "https://studafy-api-test.fly.dev/webhooks/google?x=1",
        "http://studafy-api-test.fly.dev/webhooks/google",
        "not a url",
      ]
    ) {
      expect(pubSubAudienceMatchesPushPath(wrong)).toBe(false);
    }
  });
});

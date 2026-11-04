import { describe, expect, test } from "bun:test";
import type { Sql } from "@studafy/database";
import type { PushMessage } from "@studafy/infrastructure";
import { createJsonLogger } from "@studafy/observability";
import {
  pushData,
  startChannelDelivery,
} from "../src/processors/channelDelivery";

const logger = createJsonLogger("worker", "test", "error", () => undefined);
const TOKEN = "device-token-".padEnd(48, "t");
const RECIPIENT = "c0ffee00-0000-4000-8000-0000000000a1";

/**
 * The database side as `private.channel_claim` answers it for push
 * (supabase/tests/notification_channels.sql covers the SQL itself): the
 * jobs are handed out once, and every finish succeeds.
 */
function fakeDatabase(jobs: Record<string, unknown>[]) {
  let claimed = false;
  return ((strings: TemplateStringsArray) => {
    const text = strings.join("?");
    if (text.includes("channel_claim")) {
      const handed = claimed ? [] : jobs;
      claimed = true;
      return Promise.resolve([{ jobs: handed }]);
    }
    if (text.includes("channel_finish")) {
      return Promise.resolve([{ outcome: "sent" }]);
    }
    return Promise.resolve([]);
  }) as unknown as Sql;
}

async function pushesFor(jobs: Record<string, unknown>[]) {
  const pushes: PushMessage[] = [];
  const runtime = startChannelDelivery(
    fakeDatabase(jobs),
    {
      push: {
        send: async (message) => {
          pushes.push(message);
          return { providerMessageId: "push-1" };
        },
      },
    },
    logger,
    3_600_000,
  );
  try {
    await runtime.runOnce();
  } finally {
    await runtime.close();
  }
  return pushes;
}

describe("push payload", () => {
  test("a push names the in-app notification a tap opens, and nothing else", async () => {
    const pushes = await pushesFor([{
      deliveryId: 7,
      templateKey: "communications.message_received",
      locale: "en",
      tokens: [TOKEN],
      notificationId: "1234",
      recipientId: RECIPIENT,
    }]);
    expect(pushes).toHaveLength(1);
    expect(pushes[0]?.data).toEqual({
      templateKey: "communications.message_received",
      notificationId: "1234",
      recipientId: RECIPIENT,
    });
    // The visible copy stays fixed and content-free.
    expect(pushes[0]?.title).toBe("New message");
    expect(pushes[0]?.body).toBe("You have a new message in Studafy.");
  });

  test("a job without an id still sends, with the template key alone", async () => {
    const pushes = await pushesFor([{
      deliveryId: 8,
      templateKey: "academic.grade_published",
      locale: "ar",
      tokens: [TOKEN],
      notificationId: null,
    }]);
    expect(pushes.map((push) => push.data)).toEqual([
      { templateKey: "academic.grade_published" },
    ]);
  });

  test("only the template key, the notification id and the recipient reach the payload", () => {
    const job = {
      deliveryId: 9,
      templateKey: "communications.message_received",
      locale: "en",
      notificationId: "55",
      recipientId: RECIPIENT,
      // What a careless claim might hand over must never travel in a push.
      conversationId: "c0ffee00-0000-4000-8000-000000000001",
      email: "someone@example.test",
    };
    expect(Object.keys(pushData(job)).sort()).toEqual([
      "notificationId",
      "recipientId",
      "templateKey",
    ]);
    expect(
      pushData({ templateKey: "x", notificationId: "", recipientId: null }),
    )
      .toEqual({ templateKey: "x" });
  });

  test("a phone signed in to several accounts learns which one a push is for", async () => {
    // Two accounts on one phone share its token; each gets its own push,
    // with the same fixed copy, naming only its own account.
    const OTHER = "c0ffee00-0000-4000-8000-0000000000b2";
    const pushes = await pushesFor([
      {
        deliveryId: 10,
        templateKey: "communications.message_received",
        locale: "en",
        tokens: [TOKEN],
        notificationId: "60",
        recipientId: RECIPIENT,
      },
      {
        deliveryId: 11,
        templateKey: "communications.message_received",
        locale: "en",
        tokens: [TOKEN],
        notificationId: "61",
        recipientId: OTHER,
      },
    ]);
    expect(pushes.map((push) => push.data["recipientId"])).toEqual([
      RECIPIENT,
      OTHER,
    ]);
    expect(new Set(pushes.map((push) => push.body)).size).toBe(1);
  });
});

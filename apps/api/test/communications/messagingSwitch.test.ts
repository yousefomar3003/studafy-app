/**
 * Messaging off for the whole server (DL-049, DL-061): no conversation can
 * be started and no message sent, whatever a school's own switch says, and
 * the two reads that tell the app whether messaging is on say it is off.
 */
import { describe, expect, test } from "bun:test";
import { Hono } from "hono";
import type { AuthorizationEnv } from "../../src/authorization/middleware";
import { createMessagingSwitch } from "../../src/communications/messagingSwitch";

const SCHOOL = "00000000-0000-4000-8000-0000000000bb";
const CONVERSATION = "00000000-0000-4000-8000-0000000000cc";

/** The switch in front, and routes standing in for the real modules - each
 * of which would let the request through if it got that far. */
function app(): { app: Hono<AuthorizationEnv>; reached: string[] } {
  const reached: string[] = [];
  const app = new Hono<AuthorizationEnv>();
  app.use("*", async (c, next) => {
    c.set("requestId", crypto.randomUUID());
    await next();
  });
  app.route("/", createMessagingSwitch());
  const modules = new Hono<AuthorizationEnv>();
  modules.post("/v1/conversations", (c) => {
    reached.push("createConversation");
    return c.json({ id: CONVERSATION }, 201);
  });
  modules.get("/v1/conversations", (c) => {
    reached.push("listConversations");
    return c.json({ items: [], nextCursor: null });
  });
  modules.post("/v1/conversations/:id/messages", (c) => {
    reached.push("sendMessage");
    return c.json({ id: "m" }, 201);
  });
  modules.get("/v1/conversations/:id/messages", (c) => {
    reached.push("listMessages");
    return c.json({ items: [], nextCursor: null });
  });
  modules.get(
    "/v1/control-panel/content-controls/:schoolId",
    (c) => c.json({ schoolId: SCHOOL, messagingEnabled: true, version: 3 }),
  );
  modules.get("/v1/me/guardian-links", (c) =>
    c.json({
      items: [
        { id: "l1", schoolId: SCHOOL, messagingEnabled: true },
        { id: "l2", schoolId: SCHOOL, messagingEnabled: false },
      ],
      nextCursor: null,
    }));
  app.route("/", modules);
  return { app, reached };
}

const post = (target: Hono<AuthorizationEnv>, path: string) =>
  target.request(path, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ body: "Hello" }),
  });

describe("messaging off for the whole server", () => {
  test("starting a conversation or sending a message is refused", async () => {
    const { app: target, reached } = app();
    for (
      const path of [
        "/v1/conversations",
        `/v1/conversations/${CONVERSATION}/messages`,
      ]
    ) {
      const res = await post(target, path);
      expect(res.status, path).toBe(403);
      const body = await res.json() as { code: string; detail: string };
      expect(body.code, path).toBe("MESSAGING_DISABLED");
      expect(body.detail).toBe("Messaging is not available yet.");
    }
    expect(reached).toEqual([]);
  });

  test("conversations that exist can still be read", async () => {
    const { app: target, reached } = app();
    expect((await target.request("/v1/conversations")).status).toBe(200);
    expect(
      (await target.request(`/v1/conversations/${CONVERSATION}/messages`))
        .status,
    ).toBe(200);
    expect(reached).toEqual(["listConversations", "listMessages"]);
  });

  test("a school's content controls say messaging is off", async () => {
    const res = await app().app.request(
      `/v1/control-panel/content-controls/${SCHOOL}`,
    );
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({
      schoolId: SCHOOL,
      messagingEnabled: false,
      version: 3,
    });
  });

  test("a guardian's links say messaging is off at every school", async () => {
    const res = await app().app.request("/v1/me/guardian-links");
    expect(res.status).toBe(200);
    const body = await res.json() as {
      items: { messagingEnabled: boolean }[];
    };
    expect(body.items.map((item) => item.messagingEnabled)).toEqual([
      false,
      false,
    ]);
  });
});

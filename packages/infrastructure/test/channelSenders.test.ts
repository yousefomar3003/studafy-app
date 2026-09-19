import { describe, expect, test } from "bun:test";
import {
  ChannelSendError,
  FcmPushSender,
  ResendEmailSender,
} from "../src/notifications/channelSenders";

describe("DL-053 channel senders", () => {
  test("email goes only to the fixed provider endpoint, never following redirects", async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const sender = new ResendEmailSender({
      apiKey: "re_test_key_not_real",
      from: "Studafy <no-reply@example.test>",
      fetchImpl: (async (url: string, init: RequestInit) => {
        calls.push({ url, init });
        return new Response(JSON.stringify({ id: "email-1" }), { status: 200 });
      }) as never,
    });
    const sent = await sender.send({
      to: "parent@example.test",
      subject: "New message",
      text: "You have a new message in Studafy.",
    });
    expect(sent.providerMessageId).toBe("email-1");
    expect(calls[0]?.url).toBe("https://api.resend.com/emails");
    expect(calls[0]?.init.redirect).toBe("error");
  });

  test("a rejected address is terminal and marks the target invalid", async () => {
    const sender = new ResendEmailSender({
      apiKey: "re_test_key_not_real",
      from: "x@example.test",
      fetchImpl: (async () => new Response("{}", { status: 422 })) as never,
    });
    const error = await sender.send({ to: "bad", subject: "s", text: "t" })
      .catch((e) => e);
    expect(error).toBeInstanceOf(ChannelSendError);
    expect(error.terminal).toBe(true);
    expect(error.invalidTarget).toBe(true);
  });

  test("provider outages are retryable", async () => {
    const sender = new ResendEmailSender({
      apiKey: "re_test_key_not_real",
      from: "x@example.test",
      fetchImpl: (async () => new Response("{}", { status: 503 })) as never,
    });
    const error = await sender.send({ to: "a@b.c", subject: "s", text: "t" })
      .catch((e) => e);
    expect(error.terminal).toBe(false);
  });

  test("an FCM project id cannot smuggle a different host or path", () => {
    for (const projectId of ["evil.example/x", "../../other", "A"]) {
      expect(() => new FcmPushSender({ projectId, serviceAccountJson: "{}" }))
        .toThrow(ChannelSendError);
    }
  });
});

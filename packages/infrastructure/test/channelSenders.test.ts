import { describe, expect, test } from "bun:test";
import {
  ANDROID_NOTIFICATION_CHANNEL_ID,
  ChannelSendError,
  FcmPushSender,
  fcmReason,
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

  test("a push goes to Studafy's Android channel and carries only the data it was given", async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const sender = new FcmPushSender({
      projectId: "studafy-test",
      serviceAccountJson: "{}",
      accessToken: async () => "oauth-token-not-real",
      fetchImpl: (async (url: string, init: RequestInit) => {
        calls.push({ url, init });
        return new Response(
          JSON.stringify({ name: "projects/studafy-test/messages/1" }),
          { status: 200 },
        );
      }) as never,
    });
    const sent = await sender.send({
      token: "device-token-".padEnd(40, "x"),
      title: "New message",
      body: "You have a new message in Studafy.",
      data: {
        templateKey: "communications.message",
        notificationId: "42",
        recipientId: "c0ffee00-0000-4000-8000-0000000000a1",
      },
    });
    expect(sent.providerMessageId).toBe("projects/studafy-test/messages/1");
    expect(calls[0]?.url).toBe(
      "https://fcm.googleapis.com/v1/projects/studafy-test/messages:send",
    );
    expect(calls[0]?.init.redirect).toBe("error");
    const body = JSON.parse(String(calls[0]?.init.body));
    expect(body.message.android).toEqual({
      notification: { channel_id: ANDROID_NOTIFICATION_CHANNEL_ID },
    });
    expect(ANDROID_NOTIFICATION_CHANNEL_ID).toBe("studafy_notifications");
    expect(body.message.notification).toEqual({
      title: "New message",
      body: "You have a new message in Studafy.",
    });
    expect(body.message.data).toEqual({
      templateKey: "communications.message",
      notificationId: "42",
      recipientId: "c0ffee00-0000-4000-8000-0000000000a1",
    });
  });

  test("an FCM project id cannot smuggle a different host or path", () => {
    for (const projectId of ["evil.example/x", "../../other", "A"]) {
      expect(() => new FcmPushSender({ projectId, serviceAccountJson: "{}" }))
        .toThrow(ChannelSendError);
    }
  });
});

describe("FCM's reason for a refusal (2026-11-04)", () => {
  const refusing = (status: number, body: unknown) =>
    new FcmPushSender({
      projectId: "studafy-test",
      serviceAccountJson: "{}",
      accessToken: async () => "oauth-token-not-real",
      fetchImpl: (async () =>
        new Response(JSON.stringify(body), {
          status,
        })) as unknown as typeof fetch,
    });

  test("APNs refusing the app's key is named, the code is unchanged", async () => {
    const error = await refusing(401, {
      error: {
        code: 401,
        message: "Auth error from APNS or Web Push Service",
        status: "UNAUTHENTICATED",
        details: [{
          "@type": "type.googleapis.com/google.firebase.fcm.v1.FcmError",
          errorCode: "THIRD_PARTY_AUTH_ERROR",
        }],
      },
    }).send({ token: "t", title: "a", body: "b", data: {} }).catch((e) => e);
    expect(error).toBeInstanceOf(ChannelSendError);
    expect(error.code).toBe("PROVIDER_AUTH_401");
    expect(error.detail).toBe("THIRD_PARTY_AUTH_ERROR");
  });

  test("only an upper-case code is kept, never other text", () => {
    expect(fcmReason({ error: { status: "PERMISSION_DENIED" } })).toBe(
      "PERMISSION_DENIED",
    );
    expect(fcmReason({ error: { status: "token abc123 is bad" } })).toBeNull();
    expect(fcmReason("not json")).toBeNull();
    expect(fcmReason(null)).toBeNull();
  });
});

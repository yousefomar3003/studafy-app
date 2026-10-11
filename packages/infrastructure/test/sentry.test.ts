import { describe, expect, test } from "bun:test";
import type { ErrorEvent } from "@sentry/bun";
import { logLineReport, safeFields, scrubEvent, scrubText } from "../src";

describe("Sentry reports carry nothing personal", () => {
  test("emails, tokens and long numbers are masked in text", () => {
    expect(
      scrubText(
        "duplicate key (email)=(sara.k@school.jo) for 0791234567 with " +
          "Bearer abc.def-ghi and eyJhbGciOi.eyJzdWIiOi.c2lnbmF0dXJl",
      ),
    ).toBe(
      "duplicate key (email)=([email]) for [number] with Bearer [token] " +
        "and [token]",
    );
  });

  test("only codes and ids of work survive from a log line", () => {
    expect(
      safeFields({
        event: "notification_job_exhausted",
        queue: "notifications",
        outbox_id: 12,
        error_code: "REDIS_UNAVAILABLE",
        user_id: "3bd943d1-bf92-4ee2-a8fa-7eb427fc0d2f",
        display_name: "Sara",
        ip_hash: "abc",
      }),
    ).toEqual({
      event: "notification_job_exhausted",
      queue: "notifications",
      outbox_id: 12,
      error_code: "REDIS_UNAVAILABLE",
    });
  });

  test("an event loses its user, request details and breadcrumb data", () => {
    const event = scrubEvent({
      type: undefined,
      user: { id: "u1", email: "a@b.co", ip_address: "1.2.3.4" },
      request: {
        method: "POST",
        url: "https://api.studafy.app/v1/messages?draft=hello",
        data: { body: "hello" },
        headers: { authorization: "Bearer secret" },
        cookies: { sid: "x" },
        query_string: "draft=hello",
      },
      message: "failed for a@b.co",
      exception: { values: [{ type: "Error", value: "user 12345678 bad" }] },
      breadcrumbs: [{ message: "to a@b.co", data: { url: "x" } }],
    } as ErrorEvent);

    expect(event.user).toBeUndefined();
    expect(event.request).toEqual({
      method: "POST",
      url: "https://api.studafy.app/v1/messages",
    });
    expect(event.message).toBe("failed for [email]");
    expect(event.exception?.values?.[0]?.value).toBe("user [number] bad");
    expect(event.breadcrumbs?.[0]).toEqual({ message: "to [email]" });
  });
});

describe("error log lines become grouped reports", () => {
  test("one issue per service, event and code", () => {
    const report = logLineReport(JSON.stringify({
      level: "error",
      service: "worker",
      event: "notification_job_exhausted",
      error_code: "TIMEOUT",
      outbox_id: 7,
      user_id: "someone",
    }));
    expect(report).toEqual({
      message: "notification_job_exhausted: TIMEOUT",
      fingerprint: ["worker", "notification_job_exhausted", "TIMEOUT"],
      tags: {
        service: "worker",
        event: "notification_job_exhausted",
        error_code: "TIMEOUT",
      },
      extra: {
        event: "notification_job_exhausted",
        service: "worker",
        error_code: "TIMEOUT",
        outbox_id: 7,
      },
    });
  });

  test("other levels, the API's own http_error and junk are ignored", () => {
    expect(logLineReport('{"level":"warn","event":"x"}')).toBeNull();
    expect(
      logLineReport('{"level":"error","service":"api","event":"http_error"}'),
    ).toBeNull();
    expect(logLineReport("not json")).toBeNull();
  });
});

import { describe, expect, test } from "bun:test";
import { createJsonLogger, createLogSampler } from "../src";
import { LogCollector } from "@studafy/test-support";

const request = (status: number, route: string, duration_ms = 40) => ({
  status,
  route,
  duration_ms,
});

describe("log sampling", () => {
  const never = () => 0.99;
  const always = () => 0;
  const policy = { successRate: 0.1, routineRate: 0.01, slowRequestMs: 2000 };

  test("warnings, errors and failed or slow requests are always kept", () => {
    const sample = createLogSampler({ ...policy, random: never });
    expect(sample("error", "http_error", {}).keep).toBe(true);
    expect(sample("warn", "auth_denied", {}).keep).toBe(true);
    for (const status of [400, 401, 404, 409, 429, 500, 503]) {
      expect(
        sample("info", "http_request_completed", request(status, "/v1/me"))
          .keep,
      ).toBe(true);
    }
    expect(
      sample(
        "info",
        "http_request_completed",
        request(200, "/v1/classrooms", 2500),
      ).keep,
    ).toBe(true);
  });

  test("health checks are dropped, even when the dice say keep", () => {
    const sample = createLogSampler({ ...policy, random: always });
    expect(
      sample("info", "http_request_completed", request(200, "/healthz")).keep,
    ).toBe(false);
    expect(
      sample("info", "http_request_completed", request(200, "/readyz")).keep,
    ).toBe(false);
  });

  test("successful and routine lines are sampled, and say at what rate", () => {
    const keep = createLogSampler({ ...policy, random: always });
    expect(
      keep("info", "http_request_completed", request(200, "/v1/classrooms")),
    ).toEqual({ keep: true, sampleRate: 0.1 });
    expect(
      keep(
        "info",
        "http_request_completed",
        request(200, "/v1/notifications/unread-count"),
      ),
    ).toEqual({ keep: true, sampleRate: 0.01 });
    expect(keep("info", "notification_job_completed", {})).toEqual({
      keep: true,
      sampleRate: 0.1,
    });

    const drop = createLogSampler({ ...policy, random: never });
    expect(
      drop("info", "http_request_completed", request(200, "/v1/classrooms"))
        .keep,
    ).toBe(false);
    expect(drop("info", "notification_job_completed", {}).keep).toBe(false);
  });

  test("heartbeats, startup and money lines are never sampled", () => {
    const sample = createLogSampler({ ...policy, random: never });
    for (
      const event of [
        "startup",
        "outbox_backlog",
        "file_scan_backlog",
        "billing_job_completed",
      ]
    ) {
      expect(sample("info", event, {})).toEqual({ keep: true });
    }
  });

  test("a rate of 1 keeps everything without marking it", () => {
    const sample = createLogSampler({
      successRate: 1,
      routineRate: 1,
      slowRequestMs: 2000,
      random: never,
    });
    expect(
      sample("info", "http_request_completed", request(200, "/v1/me")),
    ).toEqual({ keep: true });
  });

  test("the logger writes only kept lines, with their sample rate", () => {
    const collector = new LogCollector();
    const logger = createJsonLogger(
      "api",
      "0.1.0",
      "info",
      collector.sink,
      createLogSampler({ ...policy, random: always }),
    );
    logger.info("http_request_completed", request(200, "/healthz"));
    logger.info("http_request_completed", request(200, "/v1/me"));
    logger.info("http_request_completed", request(500, "/v1/me"));

    const lines = collector.parsed();
    expect(lines).toHaveLength(2);
    expect(lines[0]!.sample_rate).toBe(0.1);
    expect(lines[1]!.sample_rate).toBeUndefined();
  });
});

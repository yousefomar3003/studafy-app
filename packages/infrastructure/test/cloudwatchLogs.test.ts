import { describe, expect, test } from "bun:test";
import { createCloudWatchSink } from "../src/cloudwatchLogs";

interface Sent {
  kind: string;
  input: Record<string, unknown>;
}

/** Records commands and lets a test make any of them fail. */
function fakeClient(
  fail: (kind: string, call: number) => Error | null = () => null,
) {
  const sent: Sent[] = [];
  let calls = 0;
  return {
    sent,
    client: {
      send(command: unknown): Promise<unknown> {
        calls += 1;
        const kind = (command as { constructor: { name: string } }).constructor
          .name;
        const input = (command as { input: Record<string, unknown> }).input;
        const error = fail(kind, calls);
        if (error) return Promise.reject(error);
        sent.push({ kind, input });
        return Promise.resolve({});
      },
    },
  };
}

function named(name: string): Error {
  const error = new Error(name);
  error.name = name;
  return error;
}

function events(sent: Sent[]): { timestamp: number; message: string }[] {
  return sent
    .filter((entry) => entry.kind === "PutLogEventsCommand")
    .flatMap((entry) =>
      entry.input["logEvents"] as { timestamp: number; message: string }[]
    );
}

describe("cloudwatch log sink", () => {
  test("creates one stream and batches the lines into it", async () => {
    const { client, sent } = fakeClient();
    const sink = createCloudWatchSink({
      region: "il-central-1",
      logGroupName: "/studafy/application",
      client,
      now: () => 1_700_000_000_000,
    });

    sink.record('{"event":"a"}');
    sink.record('{"event":"b"}');
    sink.record('{"event":"c"}');
    await sink.flush();
    sink.close();

    const streams = sent.filter((e) => e.kind === "CreateLogStreamCommand");
    expect(streams).toHaveLength(1);
    expect(streams[0]?.input["logGroupName"]).toBe("/studafy/application");
    // One batch for three lines, not one call per line.
    expect(sent.filter((e) => e.kind === "PutLogEventsCommand")).toHaveLength(
      1,
    );
    expect(events(sent).map((e) => e.message)).toEqual([
      '{"event":"a"}',
      '{"event":"b"}',
      '{"event":"c"}',
    ]);
  });

  test("reuses the same stream across flushes", async () => {
    const { client, sent } = fakeClient();
    const sink = createCloudWatchSink({
      region: "il-central-1",
      logGroupName: "/studafy/application",
      client,
    });

    sink.record('{"event":"first"}');
    await sink.flush();
    sink.record('{"event":"second"}');
    await sink.flush();
    sink.close();

    expect(sent.filter((e) => e.kind === "CreateLogStreamCommand"))
      .toHaveLength(1);
    const streamNames = new Set(
      sent.map((entry) => entry.input["logStreamName"]),
    );
    expect(streamNames.size).toBe(1);
  });

  test("an existing stream is not an error", async () => {
    const { client, sent } = fakeClient((kind) =>
      kind === "CreateLogStreamCommand"
        ? named("ResourceAlreadyExistsException")
        : null
    );
    const failures: string[] = [];
    const sink = createCloudWatchSink({
      region: "il-central-1",
      logGroupName: "/studafy/application",
      client,
      onFailure: (message) => failures.push(message),
    });

    sink.record('{"event":"a"}');
    await sink.flush();
    sink.close();

    expect(failures).toEqual([]);
    expect(events(sent).map((e) => e.message)).toEqual(['{"event":"a"}']);
  });

  test("retries a failed put and then succeeds", async () => {
    const { client, sent } = fakeClient((kind, call) =>
      kind === "PutLogEventsCommand" && call === 2
        ? named("ThrottlingException")
        : null
    );
    const failures: string[] = [];
    const sink = createCloudWatchSink({
      region: "il-central-1",
      logGroupName: "/studafy/application",
      client,
      onFailure: (message) => failures.push(message),
    });

    sink.record('{"event":"a"}');
    await sink.flush();
    sink.close();

    expect(failures).toEqual([]);
    expect(events(sent).map((e) => e.message)).toEqual(['{"event":"a"}']);
  });

  test("a batch AWS already accepted is treated as delivered", async () => {
    const { client } = fakeClient((kind) =>
      kind === "PutLogEventsCommand"
        ? named("DataAlreadyAcceptedException")
        : null
    );
    const failures: string[] = [];
    const sink = createCloudWatchSink({
      region: "il-central-1",
      logGroupName: "/studafy/application",
      client,
      onFailure: (message) => failures.push(message),
    });

    sink.record('{"event":"a"}');
    await sink.flush();
    sink.close();

    expect(failures).toEqual([]);
  });

  test("a permanently unavailable CloudWatch never throws at the caller", async () => {
    const { client } = fakeClient(() => named("NetworkingError"));
    const failures: string[] = [];
    const sink = createCloudWatchSink({
      region: "il-central-1",
      logGroupName: "/studafy/application",
      client,
      maxAttempts: 1,
      onFailure: (message) => failures.push(message),
    });

    // The request path only ever calls record(); it must stay silent.
    expect(() => sink.record('{"event":"a"}')).not.toThrow();
    await expect(sink.flush()).resolves.toBeUndefined();
    sink.close();

    // Reported once, not once per line.
    sink.record('{"event":"b"}');
    await sink.flush();
    expect(failures).toHaveLength(1);
    expect(failures[0]).toContain("cloudwatch_logs_unavailable");
  });

  test("the buffer is bounded, dropping oldest rather than growing", async () => {
    const { client, sent } = fakeClient();
    const sink = createCloudWatchSink({
      region: "il-central-1",
      logGroupName: "/studafy/application",
      client,
      maxBufferedEvents: 2,
    });

    sink.record('{"event":"1"}');
    sink.record('{"event":"2"}');
    sink.record('{"event":"3"}');
    await sink.flush();
    sink.close();

    // The oldest line was evicted; the two most recent survive.
    expect(events(sent).map((e) => e.message)).toEqual([
      '{"event":"2"}',
      '{"event":"3"}',
    ]);
  });

  test("record() after close is inert", async () => {
    const { client, sent } = fakeClient();
    const sink = createCloudWatchSink({
      region: "il-central-1",
      logGroupName: "/studafy/application",
      client,
    });

    sink.close();
    sink.record('{"event":"late"}');
    await sink.flush();

    expect(events(sent)).toEqual([]);
  });
});

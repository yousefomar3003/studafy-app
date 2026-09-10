import { describe, expect, test } from "bun:test";
import { installGracefulShutdown, type SignalSource } from "../src";
import { createJsonLogger } from "../src";
import { LogCollector } from "@studafy/test-support";

class FakeSignals implements SignalSource {
  private listeners: Array<() => void> = [];
  on(signal: "SIGTERM" | "SIGINT", listener: () => void): void {
    void signal;
    this.listeners.push(listener);
  }
  emit(): void {
    for (const listener of this.listeners) listener();
  }
}

function build() {
  const collector = new LogCollector();
  const logger = createJsonLogger("service", "test", "debug", collector.sink);
  const signals = new FakeSignals();
  const exits: number[] = [];
  return {
    collector,
    signals,
    exits,
    install: (options: {
      onClose: () => Promise<void>;
      timeoutMs?: number;
    }) =>
      installGracefulShutdown({
        logger,
        signals,
        exit: (code) => exits.push(code),
        ...options,
      }),
  };
}

describe("graceful shutdown", () => {
  test("signal runs onClose then exits 0 with structured steps", async () => {
    const ctx = build();
    let closed = false;
    ctx.install({
      onClose: async () => {
        closed = true;
      },
    });

    ctx.signals.emit();
    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(closed).toBe(true);
    expect(ctx.exits).toEqual([0]);
    expect(ctx.collector.events()).toEqual(["shutdown", "shutdown"]);
  });

  test("a failing onClose exits 1 and logs the failure", async () => {
    const ctx = build();
    ctx.install({
      onClose: async () => {
        throw new Error("close failed");
      },
    });

    ctx.signals.emit();
    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(ctx.exits).toEqual([1]);
    const failure = ctx.collector.parsed().find(
      (entry) => entry.phase === "failed",
    );
    expect(failure?.error_message).toBe("close failed");
  });

  test("a hanging onClose hits the timeout and exits 1", async () => {
    const ctx = build();
    ctx.install({
      timeoutMs: 20,
      onClose: () => new Promise<void>(() => {}),
    });

    ctx.signals.emit();
    await new Promise((resolve) => setTimeout(resolve, 60));

    expect(ctx.exits).toEqual([1]);
    expect(
      ctx.collector.parsed().some((entry) => entry.phase === "timeout"),
    ).toBe(true);
  });

  test("a second signal during shutdown is ignored", async () => {
    const ctx = build();
    let closeCalls = 0;
    ctx.install({
      onClose: async () => {
        closeCalls += 1;
      },
    });

    ctx.signals.emit();
    ctx.signals.emit();
    await new Promise((resolve) => setTimeout(resolve, 10));

    expect(closeCalls).toBe(1);
    expect(ctx.exits).toEqual([0]);
  });
});

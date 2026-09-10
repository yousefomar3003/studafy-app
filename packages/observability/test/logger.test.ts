import { describe, expect, test } from "bun:test";
import { createJsonLogger, newRequestId } from "../src";
import { LogCollector } from "@studafy/test-support";

describe("json logger", () => {
  test("emits single-line JSON with the required envelope", () => {
    const collector = new LogCollector();
    const logger = createJsonLogger("api", "0.1.0", "info", collector.sink);
    logger.info("listening", { port: 8080 });

    expect(collector.lines).toHaveLength(1);
    const entry = collector.parsed()[0]!;
    expect(entry.timestamp).toBeString();
    expect(entry.level).toBe("info");
    expect(entry.service).toBe("api");
    expect(entry.version).toBe("0.1.0");
    expect(entry.event).toBe("listening");
    expect(entry.port).toBe(8080);
  });

  test("filters entries below the configured level", () => {
    const collector = new LogCollector();
    const logger = createJsonLogger("api", "0.1.0", "warn", collector.sink);
    logger.debug("noise");
    logger.info("noise");
    logger.warn("kept");
    logger.error("kept");
    expect(collector.events()).toEqual(["kept", "kept"]);
  });

  test("child loggers bind fields without mutating the parent", () => {
    const collector = new LogCollector();
    const logger = createJsonLogger("worker", "0.1.0", "info", collector.sink);
    const scoped = logger.child({ queue: "smoke" });
    scoped.info("job_processed", { job_id: "1" });
    logger.info("startup");

    const [first, second] = collector.parsed();
    expect(first!.queue).toBe("smoke");
    expect(first!.job_id).toBe("1");
    expect(second!.queue).toBeUndefined();
  });

  test("serializes unrepresentable values as markers instead of throwing", () => {
    const collector = new LogCollector();
    const logger = createJsonLogger("api", "0.1.0", "info", collector.sink);
    logger.info("odd", { big: 1n, fn: () => {}, undef: undefined });
    expect(collector.lines).toHaveLength(1);
    const entry = collector.parsed()[0]!;
    expect(entry.big).toBe("<bigint>");
    expect(entry.fn).toBe("<function>");
    expect(entry.undef).toBeNull();
  });
});

describe("newRequestId", () => {
  test("reuses an existing request id", () => {
    expect(newRequestId("given-id")).toBe("given-id");
  });

  test("generates a UUID-shaped id when absent", () => {
    const id = newRequestId();
    expect(id).toMatch(
      /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/,
    );
  });
});

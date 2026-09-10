/** Deterministic test primitives. No external imports; test-only helpers. */

/** Fake clock with an advancing fake "now". */
export class FakeClock {
  private currentMs: number;
  constructor(startMs = 0) {
    this.currentMs = startMs;
  }
  now(): number {
    return this.currentMs;
  }
  advance(ms: number): void {
    this.currentMs += ms;
  }
  isoNow(): string {
    return new Date(this.currentMs).toISOString();
  }
}

let uuidCounter = 0;

/** Deterministic UUID-shaped id: fixed prefix + zero-padded counter. */
export function fixedUuid(step?: number): string {
  const n = step ?? ++uuidCounter;
  return `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
}

/** Collects structured log lines emitted by a logger sink. */
export class LogCollector {
  readonly lines: string[] = [];
  readonly sink = (line: string): void => {
    this.lines.push(line);
  };
  parsed(): Record<string, unknown>[] {
    return this.lines.map((line) => JSON.parse(line) as Record<string, unknown>);
  }
  events(): string[] {
    return this.parsed().map((entry) => String(entry.event));
  }
}

/** Builds a throwaway env source for parseEnv tests. */
export function envSource(
  values: Record<string, string | undefined>,
): Record<string, string | undefined> {
  return { ...values };
}

import type {
  IdempotencyRepository,
  Reservation,
} from "../../src/platform/idempotency";

interface Entry {
  id: string;
  generation: number;
  hash: string;
  status: "reserved" | "completed" | "failed";
  responseStatus?: number;
  responseBody?: unknown;
}

export class FakeIdempotencyRepository implements IdempotencyRepository {
  readonly entries = new Map<string, Entry>();

  async reserve(
    subject: string,
    input: Parameters<IdempotencyRepository["reserve"]>[1],
  ): Promise<Reservation> {
    const mapKey = `${
      input.schoolId ?? "global"
    }:${subject}:${input.scope}:${input.key}`;
    const existing = this.entries.get(mapKey);
    if (!existing) {
      const created: Entry = {
        id: crypto.randomUUID(),
        generation: 1,
        hash: input.requestHash,
        status: "reserved",
      };
      this.entries.set(mapKey, created);
      return { outcome: "reserved", id: created.id, generation: 1 };
    }
    if (existing.hash !== input.requestHash) return { outcome: "mismatch" };
    if (existing.status === "completed") {
      return {
        outcome: "replay",
        responseStatus: existing.responseStatus!,
        responseBody: existing.responseBody,
      };
    }
    if (existing.status === "reserved") return { outcome: "inProgress" };
    existing.status = "reserved";
    existing.generation += 1;
    return {
      outcome: "reserved",
      id: existing.id,
      generation: existing.generation,
    };
  }

  async complete(
    _subject: string,
    id: string,
    generation: number,
    status: number,
    body: unknown,
  ): Promise<boolean> {
    const entry = [...this.entries.values()].find((candidate) =>
      candidate.id === id
    );
    if (
      !entry || entry.generation !== generation || entry.status !== "reserved"
    ) return false;
    entry.status = "completed";
    entry.responseStatus = status;
    entry.responseBody = body;
    return true;
  }

  async fail(
    _subject: string,
    id: string,
    generation: number,
  ): Promise<boolean> {
    const entry = [...this.entries.values()].find((candidate) =>
      candidate.id === id
    );
    if (
      !entry || entry.generation !== generation || entry.status !== "reserved"
    ) return false;
    entry.status = "failed";
    return true;
  }
}

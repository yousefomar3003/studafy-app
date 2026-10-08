/**
 * Security audit 2026-10-08: a provider reply that was produced but could
 * not be used, or a request that timed out after it was sent, used to be
 * released - free, and so free to repeat without limit. It is now settled.
 */
import { describe, expect, test } from "bun:test";
import {
  createStudyAssistant,
  StudyAssistantError,
} from "@studafy/infrastructure";
import { AiMeter } from "../../src/study/metering";
import type { StudyRepository } from "../../src/study/repository";

const prices = { inputUsdPerMTok: 0.17, outputUsdPerMTok: 0.25 };
const context = {
  subject: "7d444840-9dc0-4333-8b1a-555555555555",
  schoolId: null,
  requestId: "req",
  aal2: false,
};
const hold = { tokens: 2_000, microUsd: 400 };

function ledger() {
  const calls: { operation: string; input: Record<string, unknown> }[] = [];
  const repository: StudyRepository = {
    usage: async (_context, operation, input) => {
      calls.push({ operation, input });
      return operation === "reserve"
        ? { outcome: "ok", usageId: "u1" }
        : { outcome: "ok" };
    },
    query: async () => null,
    command: async () => ({ outcome: "ok" }) as never,
  };
  return { calls, meter: new AiMeter(repository, prices) };
}

function assistant(respond: () => Promise<Response>, timeoutMs = 5_000) {
  return createStudyAssistant({
    apiKey: "k",
    baseUrl: "https://api.together.xyz",
    model: "m",
    timeoutMs,
    fetchImpl: (async () => await respond()) as unknown as typeof fetch,
  });
}

const json = (body: unknown) =>
  new Response(JSON.stringify(body), {
    status: 200,
    headers: { "content-type": "application/json" },
  });

describe("AI failures the provider billed are charged", () => {
  test("a quiz with too few questions is settled at the reported usage", async () => {
    const { calls, meter } = ledger();
    const ai = assistant(async () =>
      json({
        choices: [{ message: { content: "Not a quiz." } }],
        usage: { prompt_tokens: 900, completion_tokens: 50 },
      })
    );
    await expect(
      meter.run(
        context,
        "study_set" as never,
        hold,
        () => ai.studySet("quiz", "Lesson", "text"),
      ),
    ).rejects.toBeInstanceOf(StudyAssistantError);
    const settled = calls.find((call) => call.operation === "settle");
    expect(settled?.input).toMatchObject({
      inputTokens: 900,
      outputTokens: 50,
    });
    expect(calls.some((call) => call.operation === "release")).toBe(false);
  });

  test("a timeout after sending is settled at the hold", async () => {
    const { calls, meter } = ledger();
    const ai = assistant(
      () =>
        new Promise<Response>((_, reject) =>
          setTimeout(
            () => reject(new DOMException("aborted", "AbortError")),
            30,
          )
        ),
      10,
    );
    await expect(
      meter.run(context, "ask", hold, () => ai.ask("q")),
    ).rejects.toBeInstanceOf(StudyAssistantError);
    const settled = calls.find((call) => call.operation === "settle");
    expect(settled?.input).toMatchObject({
      costMicroUsd: hold.microUsd,
      inputTokens: null,
    });
  });

  test("a provider refusal is still released", async () => {
    const { calls, meter } = ledger();
    const ai = assistant(async () => new Response("no", { status: 400 }));
    await expect(
      meter.run(context, "ask", hold, () => ai.ask("q")),
    ).rejects.toBeInstanceOf(StudyAssistantError);
    expect(calls.map((call) => call.operation)).toEqual(["reserve", "release"]);
  });
});

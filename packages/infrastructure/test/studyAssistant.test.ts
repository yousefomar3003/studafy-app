/**
 * The study assistant's outbound call.
 *
 * ADR-0026 removed the previous AI integration after it became the SEC-001
 * critical vulnerability: it sent to whatever a URL variable named, and it
 * forwarded lesson-material bodies unredacted. These tests pin the two
 * properties that stop that recurring, so neither can be quietly lost.
 */
import { describe, expect, test } from "bun:test";
import { redactForProvider } from "@studafy/domain";
import {
  createStudyAssistant,
  StudyAssistantError,
} from "../src/studyAssistant";

const BASE = "https://api.together.xyz";

function assistantWith(fetchImpl: typeof fetch) {
  return createStudyAssistant({
    apiKey: "test-key",
    baseUrl: BASE,
    model: "Qwen/Qwen2.5-7B-Instruct-Turbo",
    fetchImpl,
  });
}

function reply(content: string): Response {
  return new Response(
    JSON.stringify({ choices: [{ message: { content } }] }),
    { status: 200, headers: { "content-type": "application/json" } },
  );
}

describe("study assistant egress", () => {
  test("only ever calls the configured origin", async () => {
    const calls: string[] = [];
    const assistant = assistantWith(
      (async (input: unknown) => {
        calls.push(new URL(input as URL).origin);
        return reply("ok");
      }) as typeof fetch,
    );

    await assistant.ask("What is photosynthesis?");

    expect(calls).toEqual([BASE]);
  });

  test("refuses a base url that is not https", () => {
    expect(() =>
      createStudyAssistant({
        apiKey: "k",
        baseUrl: "http://api.together.xyz",
        model: "m",
      })
    ).toThrow();
  });

  test("sends only the question, never an identifier the app holds", async () => {
    const sent: Record<string, unknown>[] = [];
    const assistant = assistantWith(
      (async (_input, init) => {
        sent.push(JSON.parse((init as RequestInit).body as string));
        return reply("ok");
      }) as typeof fetch,
    );

    await assistant.ask("Explain quadratic equations");

    const body = sent[0] as { messages: { content: string }[] };
    const messages = body.messages;
    const payload = JSON.stringify(body);
    expect(messages).toHaveLength(2);
    expect(messages[1]!.content).toBe("Explain quadratic equations");
    // Nothing school-shaped may ride along: this is the whole prompt.
    for (const forbidden of ["schoolId", "studentId", "userId", "classroom"]) {
      expect(payload).not.toContain(forbidden);
    }
  });

  test("a follow-up carries the chat it is given, redacted, in order", async () => {
    // The route has already fitted the chat to the plan's memory budget;
    // this layer forwards it as it is, redacting both sides.
    const sent: { messages: { role: string; content: string }[] }[] = [];
    const assistant = assistantWith(
      (async (_input, init) => {
        sent.push(JSON.parse((init as RequestInit).body as string));
        return reply("ok");
      }) as typeof fetch,
    );
    const history = Array.from({ length: 12 }, (_, i) => ({
      role: i % 2 === 0 ? "student" as const : "assistant" as const,
      text: i === 11 ? "Write to me at kid@example.com" : `turn ${i}`,
    }));

    await assistant.ask("What does that mean?", history);

    const messages = sent[0]!.messages;
    // System, all twelve turns, then the question.
    expect(messages).toHaveLength(14);
    expect(messages[0]!.role).toBe("system");
    expect(messages[1]).toEqual({ role: "user", content: "turn 0" });
    expect(messages[2]).toEqual({ role: "assistant", content: "turn 1" });
    expect(messages[12]!.content).toBe("Write to me at [email]");
    expect(messages[13]).toEqual({
      role: "user",
      content: "What does that mean?",
    });
  });

  test("asks for an answer without a reasoning trace", async () => {
    // A thinking model spends the token budget on its reasoning; with it on,
    // students got cut-off or empty answers.
    const sent: Record<string, unknown>[] = [];
    const assistant = assistantWith(
      (async (_input, init) => {
        sent.push(JSON.parse((init as RequestInit).body as string));
        return reply("ok");
      }) as typeof fetch,
    );
    await assistant.ask("What is photosynthesis?");
    expect(sent[0]?.["reasoning"]).toEqual({ enabled: false });
  });

  test("obvious identifiers are stripped before egress", () => {
    const redacted = redactForProvider(
      "I am rara@gmail.com, id 1234567890, see https://drive.example/mine",
    );
    expect(redacted).not.toContain("rara@gmail.com");
    expect(redacted).not.toContain("1234567890");
    expect(redacted).not.toContain("drive.example");
    expect(redacted).toContain("[email]");
  });

  test("a provider failure surfaces as unavailable, never as a crash", async () => {
    const assistant = assistantWith(
      (async () =>
        new Response("nope", { status: 500 })) as unknown as typeof fetch,
    );

    await expect(assistant.ask("hello there")).rejects.toBeInstanceOf(
      StudyAssistantError,
    );
  });

  test("an empty answer is a failure rather than a blank reply", async () => {
    const assistant = assistantWith(
      (async () => reply("   ")) as unknown as typeof fetch,
    );
    await expect(assistant.ask("hello there")).rejects.toMatchObject({
      kind: "empty",
    });
  });
});

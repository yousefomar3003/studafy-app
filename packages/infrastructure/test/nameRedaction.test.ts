/**
 * Names never reach the provider (ADR-0043, DPIA D1): the whole request
 * body the HTTP client sends is checked, for every kind of call that
 * carries text.
 */
import { describe, expect, test } from "bun:test";
import { nameRedactor } from "@studafy/domain";
import { createStudyAssistant, withNameRedaction } from "../src/studyAssistant";

const NAMES = [
  { name: "Sara Haddad", kind: "self" as const },
  { name: "Omar Haddad", kind: "parent" as const },
  { name: "Grace Hopper", kind: "teacher" as const },
  { name: "يوسف الخطيب", kind: "classmate" as const },
];

function capturing() {
  const bodies: string[] = [];
  const fetchImpl = (async (_input: unknown, init?: RequestInit) => {
    bodies.push(String(init?.body ?? ""));
    const content = String(init?.body ?? "").includes("JSON only")
      ? JSON.stringify({
        questions: [0, 1, 2].map((n) => ({
          question: `Q${n}`,
          options: ["a", "b", "c", "d"],
          answerIndex: 0,
          explanation: "e",
        })),
        cards: [0, 1, 2, 3].map((n) => ({ front: `f${n}`, back: "b" })),
      })
      : "An answer.";
    return new Response(
      JSON.stringify({ choices: [{ message: { content } }] }),
      { status: 200, headers: { "content-type": "application/json" } },
    );
  }) as typeof fetch;
  const assistant = withNameRedaction(
    createStudyAssistant({
      apiKey: "test-key",
      baseUrl: "https://api.together.xyz",
      model: "m",
      fetchImpl,
    }),
    (text) => nameRedactor(NAMES).redact(text),
  );
  return { assistant, bodies };
}

function expectNoNames(body: string) {
  for (const word of ["Sara", "Omar", "Haddad", "Grace", "Hopper", "يوسف"]) {
    expect(body).not.toContain(word);
  }
}

describe("a name-redacting assistant", () => {
  test("the question, the chat and the material carry no names", async () => {
    const { assistant, bodies } = capturing();
    await assistant.ask(
      "My dad Omar Haddad says I, Sara, should ask Grace Hopper",
      [
        { role: "student", text: "Hi, I am Sara" },
        { role: "assistant", text: "Hello Sara!" },
      ],
      {
        passages: [{
          sourceKind: "file",
          name: "Sara Haddad notes.pdf",
          lessonTitle: "Grace Hopper's lesson",
          heading: "Written by يوسف الخطيب",
          text: "Group: Sara Haddad, يوسف الخطيب. Teacher: Grace Hopper.",
        }],
        unreadable: [{ name: "Omar's scan.pdf", reason: "unreadable" }],
      },
    );
    expect(bodies).toHaveLength(1);
    expectNoNames(bodies[0]!);
    expect(bodies[0]).toContain("[student]");
    expect(bodies[0]).toContain("[parent]");
    expect(bodies[0]).toContain("[teacher]");
    expect(bodies[0]).toContain("[classmate]");
  });

  test("study sets, lesson notes and notebooks carry no names", async () => {
    const { assistant, bodies } = capturing();
    const text = "Sara Haddad and يوسف الخطيب presented. ".repeat(3);
    await assistant.studySet("quiz", "Grace Hopper's class", text);
    await assistant.studySet("flashcards", "Grace Hopper's class", text);
    await assistant.lessonNotes("Omar Haddad visit", text);
    await assistant.notebook("Grace Hopper's class", [{
      sourceKind: "lesson",
      name: "Sara's lesson",
      text,
    }]).catch(() => {});
    expect(bodies).toHaveLength(4);
    for (const body of bodies) expectNoNames(body);
  });

  test("a photo is sent as it is: nothing can be taken out of it", async () => {
    const { assistant, bodies } = capturing();
    await assistant.whiteboardNotes(new Uint8Array([1, 2, 3]), "image/png");
    expect(bodies[0]).toContain("data:image/png;base64,AQID");
  });
});

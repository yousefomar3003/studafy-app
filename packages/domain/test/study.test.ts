import { describe, expect, test } from "bun:test";
import {
  isUnreadableReply,
  lessonPrompt,
  parseFlashcards,
  parseQuiz,
  STUDY_LESSON_MAX_CHARS,
} from "../src/index";

describe("study content policy", () => {
  test("a quiz keeps only well-formed questions", () => {
    const reply = "```json\n" + JSON.stringify({
      questions: [
        {
          question: "Where does photosynthesis happen?",
          options: ["Chloroplasts", "Roots", "Nucleus", "Stem"],
          answerIndex: 0,
          explanation: "In the chloroplasts.",
        },
        // Three options, and an answer out of range: both dropped.
        { question: "Bad", options: ["a", "b", "c"], answerIndex: 0 },
        { question: "Worse", options: ["a", "b", "c", "d"], answerIndex: 7 },
      ],
    }) + "\n```";
    const quiz = parseQuiz(reply);
    expect(quiz).toHaveLength(1);
    expect(quiz[0]?.answerIndex).toBe(0);
  });

  test("a reply that is not JSON yields nothing rather than throwing", () => {
    expect(parseQuiz("Sorry, I cannot do that.")).toEqual([]);
    expect(parseFlashcards("{not json")).toEqual([]);
  });

  test("a card missing its opening brace does not lose the rest", () => {
    // The model's own reply on the test copy (2026-11-03): only the first
    // two cards parsed as JSON, and the set failed for too few cards.
    const reply = `{
  "cards": [
    { "front": "What process do plants use to make their own food?", "back": "Photosynthesis" },
    { "front": "Where does photosynthesis take place?", "back": "Chloroplasts" },
      "front": "Which pigment absorbs light energy?", "back": "Chlorophyll"
    },
    { "front": "How does carbon dioxide enter the plant?", "back": "Through the stomata" },
    { "front": "What are the products?", "back": "Glucose and \\"oxygen\\"" }
  ]
}`;
    const cards = parseFlashcards(reply);
    expect(cards.map((c) => c.front)).toEqual([
      "What process do plants use to make their own food?",
      "Where does photosynthesis take place?",
      "Which pigment absorbs light energy?",
      "How does carbon dioxide enter the plant?",
      "What are the products?",
    ]);
    expect(cards[4]!.back).toBe('Glucose and "oxygen"');
  });

  test("recovered cards keep the same rules: both sides, no repeats", () => {
    const reply =
      '{"cards":[{"front":"A","back":"B"},"front":"A","back":"C"},' +
      '"front":"Same","back":"same"},"front":"D","back":""}';
    expect(parseFlashcards(reply)).toEqual([{ front: "A", back: "B" }]);
  });

  test("flashcards need both sides", () => {
    const cards = parseFlashcards(JSON.stringify({
      cards: [{ front: "Chlorophyll", back: "The green pigment" }, {
        front: "No back",
      }],
    }));
    expect(cards).toEqual([{
      front: "Chlorophyll",
      back: "The green pigment",
    }]);
  });

  test("a blank board is recognised", () => {
    expect(isUnreadableReply("  UNREADABLE \n")).toBe(true);
    expect(isUnreadableReply("# Notes\n- UNREADABLE is a word")).toBe(false);
  });

  test("a lesson is redacted and bounded before it is sent", () => {
    const prompt = lessonPrompt(
      "Cells",
      "Email me at kid@example.com " + "x".repeat(STUDY_LESSON_MAX_CHARS * 2),
    );
    expect(prompt).not.toContain("kid@example.com");
    expect(prompt.length).toBeLessThan(STUDY_LESSON_MAX_CHARS + 100);
  });
});

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

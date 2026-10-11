import { describe, expect, test } from "bun:test";
import {
  notebookText,
  parseFlashcards,
  parseNotebook,
  parseQuiz,
} from "../src";

/** Study notebooks and study sets from a model's untrusted JSON. */
const passages = [
  { sourceKind: "file" as const, name: "Cells.pdf", page: 2, text: "..." },
  { sourceKind: "file" as const, name: "Deck.pptx", slide: 4, text: "..." },
];

describe("a notebook from a model's reply", () => {
  const reply = JSON.stringify({
    overview: "How plant cells make food.",
    objectives: [
      "Describe photosynthesis",
      "Describe photosynthesis",
      "Name the organelles",
    ],
    keyTerms: [
      {
        term: "Chlorophyll",
        definition: "Green pigment that absorbs light.",
        source: "S1",
      },
      { term: "Chlorophyll", definition: "Duplicate.", source: "S1" },
      { term: "", definition: "No term." },
    ],
    sections: [
      {
        heading: "Light reactions",
        paragraphs: ["Light splits water."],
        sources: ["S1", "S9"],
      },
      { heading: "Light reactions", paragraphs: ["Same heading again."] },
      { heading: "Empty", paragraphs: [], points: [] },
      {
        heading: "Why it matters",
        paragraphs: ["All food chains start here."],
        extra: true,
      },
    ],
    examples: [{
      title: "Balance the equation",
      steps: ["6CO2 + 6H2O", "→ C6H12O6 + 6O2"],
      source: "S2",
    }],
    facts: ["Oxygen is released.", { text: "Glucose is made.", source: "S2" }],
    mistakes: [{ text: "Plants do not get food from soil.", extra: true }],
    summary: ["Light energy becomes chemical energy."],
  });

  test("keeps each part once, and only parts with content", () => {
    const notebook = parseNotebook("```json\n" + reply + "\n```", passages)!;
    expect(notebook.objectives).toEqual([
      "Describe photosynthesis",
      "Name the organelles",
    ]);
    expect(notebook.keyTerms.map((t) => t.term)).toEqual(["Chlorophyll"]);
    expect(notebook.sections.map((s) => s.heading)).toEqual([
      "Light reactions",
      "Why it matters",
    ]);
    expect(notebook.facts.map((f) => f.text)).toEqual([
      "Oxygen is released.",
      "Glucose is made.",
    ]);
  });

  test("resolves only labels it was given, and marks what is extra", () => {
    const notebook = parseNotebook(reply, passages)!;
    expect(notebook.sections[0]!.cites).toEqual([{
      name: "Cells.pdf",
      page: 2,
      slide: null,
    }]);
    expect(notebook.sections[1]!.extra).toBe(true);
    expect(notebook.examples[0]!.cite).toEqual({
      name: "Deck.pptx",
      page: null,
      slide: 4,
    });
    expect(notebook.mistakes[0]!.extra).toBe(true);
  });

  test("section keys stay put while the heading does", () => {
    const a = parseNotebook(reply, passages)!;
    const b = parseNotebook(reply, passages)!;
    expect(a.sections.map((s) => s.key)).toEqual(b.sections.map((s) => s.key));
    expect(new Set(a.sections.map((s) => s.key)).size).toBe(2);
  });

  test("nothing usable is no notebook", () => {
    expect(parseNotebook("I cannot help with that.", passages)).toBeNull();
    expect(
      parseNotebook(JSON.stringify({ sections: [{ heading: "x" }] }), passages),
    ).toBeNull();
  });

  test("its text for practice can be narrowed to chosen sections", () => {
    const notebook = parseNotebook(reply, passages)!;
    const key = notebook.sections[0]!.key;
    const only = notebookText(notebook, [key]);
    expect(only).toContain("Light splits water.");
    expect(only).not.toContain("All food chains");
    expect(notebookText(notebook)).toContain("Common mistakes");
  });
});

describe("quizzes and flashcards", () => {
  test("drop duplicate questions and questions with repeated options", () => {
    const q = (question: string, options: string[]) => ({
      question,
      options,
      answerIndex: 0,
      explanation: "",
    });
    const parsed = parseQuiz(JSON.stringify({
      questions: [
        q("What is a cell?", ["a", "b", "c", "d"]),
        q("what is a  cell?", ["a", "b", "c", "d"]),
        q("Which organelle?", ["Nucleus", "nucleus", "Wall", "Root"]),
      ],
    }));
    expect(parsed.map((p) => p.question)).toEqual(["What is a cell?"]);
  });

  test("drop duplicate cards and cards that answer themselves", () => {
    const parsed = parseFlashcards(JSON.stringify({
      cards: [
        { front: "Cell", back: "The unit of life" },
        { front: "cell", back: "Again" },
        { front: "ATP", back: "atp" },
      ],
    }));
    expect(parsed).toEqual([{ front: "Cell", back: "The unit of life" }]);
  });

  test("a reply cut off at the length limit keeps its finished questions", () => {
    const whole = JSON.stringify({
      questions: ["One", "Two", "Three"].map((n) => ({
        question: `Question ${n}?`,
        options: ["a", "b", "c", "d"],
        answerIndex: 1,
        explanation: "Because.",
      })),
    });
    const cut = whole.slice(0, whole.lastIndexOf("Question Three") + 12);
    expect(parseQuiz(cut).map((q) => q.question)).toEqual([
      "Question One?",
      "Question Two?",
    ]);
    expect(
      parseFlashcards('{"cards":[{"front":"A","back":"B"},{"front":"C","ba'),
    )
      .toEqual([{ front: "A", back: "B" }]);
    expect(parseQuiz("no json here")).toEqual([]);
  });
});

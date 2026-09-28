/**
 * What Studafy asks an AI model and what it accepts back (ADR-0029).
 *
 * Pure policy: the instructions each feature sends, what is stripped from a
 * student's text before it leaves, and how a model's reply is checked before
 * a student sees it. The HTTP client that carries these lives in
 * @studafy/infrastructure; nothing here does I/O.
 */

/** Obvious identifiers are stripped before anything leaves the building. */
const EMAIL = /[\w.+-]+@[\w-]+\.[\w.-]+/g;
// Long digit runs: phone numbers, national ids, anything that looks like one.
const LONG_NUMBER = /\b\d{7,}\b/g;
const URL_LIKE = /\bhttps?:\/\/\S+/gi;

/** What the provider reported one call cost, in tokens. */
export interface StudyUsage {
  inputTokens: number;
  outputTokens: number;
  model: string;
}

export interface QuizQuestion {
  question: string;
  options: string[];
  answerIndex: number;
  explanation: string;
}

export interface Flashcard {
  front: string;
  back: string;
}

export type StudySetKind = "quiz" | "flashcards";

/**
 * Removes what a student might paste in without thinking.
 *
 * Not a guarantee - free text can always carry something - but it keeps the
 * obvious identifiers out of an outbound request, which is the difference
 * between a best effort and no effort.
 */
export function redactForProvider(text: string): string {
  return text
    .replace(EMAIL, "[email]")
    .replace(URL_LIKE, "[link]")
    .replace(LONG_NUMBER, "[number]");
}

/** The instructions sent with each kind of request. */
export const STUDY_PROMPTS = {
  ask: [
    "You are a study helper for school students.",
    "Explain clearly and briefly, at the level of the question,",
    "in no more than about 250 words.",
    "Help the student understand and practise; do not simply hand over answers",
    "to what is obviously graded homework - walk through the method instead.",
    "If a question is not about schoolwork, say so and stop.",
    "Never ask for personal details.",
  ].join(" "),
  whiteboard: [
    "You turn a photo of a classroom whiteboard into clear study notes in",
    "Markdown for a school student. Transcribe what is written faithfully and",
    "organise it with a title, short headings and bullet points. Keep formulas",
    "exact. Do not add facts that are not on the board. If the photo shows no",
    "readable writing, reply with exactly: UNREADABLE",
  ].join(" "),
  quiz: [
    "You write a short multiple-choice quiz for a school student from the",
    "lesson below. Use only what the lesson says. Reply with JSON only, no",
    'prose: {"questions":[{"question":"...","options":["...","...","...","..."],',
    '"answerIndex":0,"explanation":"..."}]}. Exactly 4 options each, one',
    "correct. Exactly 6 questions. Keep each explanation to one short",
    "sentence.",
  ].join(" "),
  flashcards: [
    "You write revision flashcards for a school student from the lesson",
    "below. Use only what the lesson says. Reply with JSON only, no prose:",
    '{"cards":[{"front":"...","back":"..."}]}. Between 6 and 12 cards; a',
    "front is a term or question, a back is a short answer.",
  ].join(" "),
} as const;

/** The longest lesson text sent for a study set, in characters. */
export const STUDY_LESSON_MAX_CHARS = 16000;

/** A whiteboard reply that means "there was nothing readable". */
export function isUnreadableReply(text: string): boolean {
  return /^\s*UNREADABLE\s*$/.test(text);
}

/** The lesson as sent for a study set: redacted and length-bounded. */
export function lessonPrompt(title: string, lessonText: string): string {
  return `Lesson: ${redactForProvider(title)}\n\n${
    redactForProvider(lessonText).slice(0, STUDY_LESSON_MAX_CHARS)
  }`;
}

/** A reply's JSON, tolerating a fenced code block around it; null if none. */
function parseJsonReply(text: string): unknown {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const raw = (fenced ? fenced[1]! : text).trim();
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  if (start < 0 || end <= start) return null;
  try {
    return JSON.parse(raw.slice(start, end + 1));
  } catch {
    return null;
  }
}

function clip(value: unknown, max: number): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed.slice(0, max);
}

/**
 * The well-formed questions in a quiz reply. A model's JSON is untrusted
 * input: anything missing a field, with the wrong number of options or an
 * answer index out of range is dropped rather than shown to a student as a
 * broken question.
 */
export function parseQuiz(reply: string): QuizQuestion[] {
  const list = (parseJsonReply(reply) as { questions?: unknown } | null)
    ?.questions;
  if (!Array.isArray(list)) return [];
  const out: QuizQuestion[] = [];
  for (const item of list.slice(0, 30)) {
    const q = item as Record<string, unknown>;
    const question = clip(q["question"], 500);
    const options = Array.isArray(q["options"])
      ? (q["options"] as unknown[]).map((o) => clip(o, 200))
      : [];
    const answerIndex = q["answerIndex"];
    if (
      !question || options.length !== 4 || options.some((o) => o === null) ||
      typeof answerIndex !== "number" || !Number.isInteger(answerIndex) ||
      answerIndex < 0 || answerIndex > 3
    ) continue;
    out.push({
      question,
      options: options as string[],
      answerIndex,
      explanation: clip(q["explanation"], 600) ?? "",
    });
  }
  return out;
}

/** The well-formed cards in a flashcards reply. */
export function parseFlashcards(reply: string): Flashcard[] {
  const list = (parseJsonReply(reply) as { cards?: unknown } | null)?.cards;
  if (!Array.isArray(list)) return [];
  const out: Flashcard[] = [];
  for (const item of list.slice(0, 30)) {
    const c = item as Record<string, unknown>;
    const front = clip(c["front"], 300);
    const back = clip(c["back"], 600);
    if (front && back) out.push({ front, back });
  }
  return out;
}

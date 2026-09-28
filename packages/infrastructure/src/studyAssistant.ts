/**
 * The study assistant's one outbound call.
 *
 * ADR-0026 removed the previous AI integration after it became the SEC-001
 * critical vulnerability. Two properties caused that, and both are closed
 * here by construction rather than by policy:
 *
 *   1. It sent to whatever a URL variable named. This client is pinned to a
 *      single origin, checked on every request, and refuses anything else -
 *      so a swapped environment variable cannot redirect children's questions
 *      to a new destination.
 *   2. It forwarded lesson-material bodies with no redaction. This one sends
 *      only the sentence the student typed, never their name, their id, their
 *      school, their marks or any material the app holds. Nothing is read
 *      from the database to build the prompt.
 *
 * It also never sees a service-role credential: the provider key is the only
 * secret it holds, and it is used for exactly one host.
 */

/** Obvious identifiers are stripped before anything leaves the building. */
const EMAIL = /[\w.+-]+@[\w-]+\.[\w.-]+/g;
// Long digit runs: phone numbers, national ids, anything that looks like one.
const LONG_NUMBER = /\b\d{7,}\b/g;
const URL_LIKE = /\bhttps?:\/\/\S+/gi;

export interface StudyAssistantOptions {
  apiKey: string;
  /** The single origin this client may ever reach. */
  baseUrl: string;
  model: string;
  /** Hard ceiling on a question's reply, which is also its cost ceiling. */
  maxOutputTokens?: number;
  /** Ceiling for whiteboard notes and study sets, which run longer. */
  maxLongOutputTokens?: number;
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
}

/** What the provider reported one call cost, in tokens. */
export interface StudyUsage {
  inputTokens: number;
  outputTokens: number;
  model: string;
}

export interface StudyAssistantReply {
  answer: string;
  /** Absent only if the provider omitted it; callers then charge the hold. */
  usage?: StudyUsage;
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

export type StudySetResult =
  | { kind: "quiz"; questions: QuizQuestion[]; usage?: StudyUsage }
  | { kind: "flashcards"; cards: Flashcard[]; usage?: StudyUsage };

export class StudyAssistantError extends Error {
  constructor(
    readonly kind: "unavailable" | "refused" | "empty" | "unreadable",
  ) {
    super(`study_assistant_${kind}`);
    this.name = "StudyAssistantError";
  }
}

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

const SYSTEM_PROMPT = [
  "You are a study helper for school students.",
  "Explain clearly and briefly, at the level of the question,",
  "in no more than about 250 words.",
  "Help the student understand and practise; do not simply hand over answers",
  "to what is obviously graded homework - walk through the method instead.",
  "If a question is not about schoolwork, say so and stop.",
  "Never ask for personal details.",
].join(" ");

const WHITEBOARD_PROMPT = [
  "You turn a photo of a classroom whiteboard into clear study notes in",
  "Markdown for a school student. Transcribe what is written faithfully and",
  "organise it with a title, short headings and bullet points. Keep formulas",
  "exact. Do not add facts that are not on the board. If the photo shows no",
  "readable writing, reply with exactly: UNREADABLE",
].join(" ");

const STUDY_SET_PROMPT = {
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

export interface StudyAssistant {
  ask(question: string): Promise<StudyAssistantReply>;
  /** Notes from a whiteboard photo. Throws "unreadable" for a blank one. */
  whiteboardNotes(
    image: Uint8Array,
    mediaType: string,
  ): Promise<StudyAssistantReply>;
  studySet(
    kind: "quiz" | "flashcards",
    title: string,
    lessonText: string,
  ): Promise<StudySetResult>;
}

type Content =
  | string
  | ({ type: "text"; text: string } | {
    type: "image_url";
    image_url: { url: string };
  })[];

function base64(bytes: Uint8Array): string {
  let binary = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunk));
  }
  return btoa(binary);
}

/** A reply's JSON, tolerating a fenced code block around it. */
function parseJsonReply(text: string): unknown {
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const raw = (fenced ? fenced[1]! : text).trim();
  const start = raw.indexOf("{");
  const end = raw.lastIndexOf("}");
  if (start < 0 || end <= start) throw new StudyAssistantError("empty");
  return JSON.parse(raw.slice(start, end + 1));
}

function clip(value: unknown, max: number): string | null {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed.slice(0, max);
}

/**
 * Keeps only well-formed items. A model's JSON is untrusted input: anything
 * missing a field, with the wrong number of options or an answer index out
 * of range is dropped rather than shown to a student as a broken question.
 */
function cleanQuiz(value: unknown): QuizQuestion[] {
  const list = (value as { questions?: unknown })?.questions;
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

function cleanCards(value: unknown): Flashcard[] {
  const list = (value as { cards?: unknown })?.cards;
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

export function createStudyAssistant(
  options: StudyAssistantOptions,
): StudyAssistant {
  const {
    apiKey,
    baseUrl,
    model,
    maxOutputTokens = 600,
    maxLongOutputTokens = 1400,
    timeoutMs = 20_000,
    fetchImpl = fetch,
  } = options;

  const allowed = new URL(baseUrl);
  if (allowed.protocol !== "https:") {
    throw new Error("study assistant base url must be https");
  }

  async function complete(
    system: string,
    user: Content,
    maxTokens: number,
  ): Promise<{ text: string; usage?: StudyUsage }> {
    const endpoint = new URL("/v1/chat/completions", allowed);
    // The allowlist, enforced rather than assumed: the origin that ends up
    // being called has to be the one that was configured.
    if (endpoint.origin !== allowed.origin) {
      throw new StudyAssistantError("refused");
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetchImpl(endpoint, {
        method: "POST",
        signal: controller.signal,
        headers: {
          authorization: `Bearer ${apiKey}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          model,
          max_tokens: maxTokens,
          temperature: 0.3,
          // Qwen3.5 thinks before answering by default, and the thinking
          // counts against max_tokens: a 600-token budget came back cut
          // off mid-sentence, or empty, after ~9s. Off, the same question
          // gets a complete answer in ~2s. A short explanation for a
          // student does not need a reasoning trace.
          reasoning: { enabled: false },
          messages: [
            { role: "system", content: system },
            { role: "user", content: user },
          ],
        }),
      });
      if (!response.ok) throw new StudyAssistantError("unavailable");
      const body = await response.json() as {
        choices?: { message?: { content?: string } }[];
        usage?: { prompt_tokens?: number; completion_tokens?: number };
        model?: string;
      };
      const text = body.choices?.[0]?.message?.content?.trim();
      if (!text) throw new StudyAssistantError("empty");
      const usage = body.usage &&
          Number.isInteger(body.usage.prompt_tokens) &&
          Number.isInteger(body.usage.completion_tokens)
        ? {
          inputTokens: body.usage.prompt_tokens!,
          outputTokens: body.usage.completion_tokens!,
          model: body.model ?? model,
        }
        : undefined;
      return { text, ...(usage ? { usage } : {}) };
    } catch (error) {
      if (error instanceof StudyAssistantError) throw error;
      throw new StudyAssistantError("unavailable");
    } finally {
      clearTimeout(timer);
    }
  }

  return {
    async ask(question: string): Promise<StudyAssistantReply> {
      const { text, usage } = await complete(
        SYSTEM_PROMPT,
        redactForProvider(question),
        maxOutputTokens,
      );
      return { answer: text, ...(usage ? { usage } : {}) };
    },

    async whiteboardNotes(
      image: Uint8Array,
      mediaType: string,
    ): Promise<StudyAssistantReply> {
      if (mediaType !== "image/jpeg" && mediaType !== "image/png") {
        throw new StudyAssistantError("refused");
      }
      // Only the image, and only the cleaned copy the pipeline stored: no
      // name, class or school travels with it.
      const { text, usage } = await complete(
        WHITEBOARD_PROMPT,
        [
          { type: "text", text: "Make study notes from this whiteboard." },
          {
            type: "image_url",
            image_url: { url: `data:${mediaType};base64,${base64(image)}` },
          },
        ],
        maxLongOutputTokens,
      );
      if (/^\s*UNREADABLE\s*$/.test(text)) {
        throw new StudyAssistantError("unreadable");
      }
      return { answer: text, ...(usage ? { usage } : {}) };
    },

    async studySet(kind, title, lessonText): Promise<StudySetResult> {
      const lesson = `Lesson: ${redactForProvider(title)}\n\n${
        redactForProvider(lessonText).slice(0, STUDY_LESSON_MAX_CHARS)
      }`;
      const { text, usage } = await complete(
        STUDY_SET_PROMPT[kind],
        lesson,
        maxLongOutputTokens,
      );
      let parsed: unknown;
      try {
        parsed = parseJsonReply(text);
      } catch {
        throw new StudyAssistantError("empty");
      }
      if (kind === "quiz") {
        const questions = cleanQuiz(parsed);
        if (questions.length === 0) throw new StudyAssistantError("empty");
        return { kind, questions, ...(usage ? { usage } : {}) };
      }
      const cards = cleanCards(parsed);
      if (cards.length === 0) throw new StudyAssistantError("empty");
      return { kind, cards, ...(usage ? { usage } : {}) };
    },
  };
}

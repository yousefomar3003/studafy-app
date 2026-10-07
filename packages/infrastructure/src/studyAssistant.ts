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
 *      what the student typed, the last few turns of the same chat, and -
 *      behind AI_LESSON_TOOLS_ENABLED (ADR-0029, ADR-0037) - passages of
 *      the class material that student may read, all redacted. Material is
 *      wrapped as labelled data the model is told never to obey. Never the
 *      student's name, id, school or marks.
 *
 * It also never sees a service-role credential: the provider key is the only
 * secret it holds, and it is used for exactly one host.
 */

import {
  type Flashcard,
  GROUNDED_RULES,
  isUnreadableReply,
  learnerLine,
  type LearnerProfile,
  lessonPrompt,
  materialBlock,
  type MaterialPassage,
  NOTEBOOK_PROMPT,
  type NotebookContent,
  parseFlashcards,
  parseNotebook,
  parseQuiz,
  type QuizQuestion,
  redactForProvider,
  STUDY_PROMPTS,
  type StudySetKind,
  type StudyUsage,
  type UnreadableSource,
} from "@studafy/domain";

export interface StudyAssistantOptions {
  apiKey: string;
  /** The single origin this client may ever reach. */
  baseUrl: string;
  model: string;
  /** Hard ceiling on a question's reply, which is also its cost ceiling. */
  maxOutputTokens?: number;
  /** Ceiling for whiteboard notes and study sets, which run longer. */
  maxLongOutputTokens?: number;
  /** A whole notebook: its output ceiling and time, run in the background. */
  notebookOutputTokens?: number;
  /** A quiz or flashcards: six questions with explanations in Arabic need
   * more room than an answer. */
  studySetOutputTokens?: number;
  notebookTimeoutMs?: number;
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
}

export interface StudyAssistantReply {
  answer: string;
  /** Absent only if the provider omitted it; callers then charge the hold. */
  usage?: StudyUsage;
}

export type StudySetResult =
  | { kind: "quiz"; questions: QuizQuestion[]; usage?: StudyUsage }
  | { kind: "flashcards"; cards: Flashcard[]; usage?: StudyUsage };

export class StudyAssistantError extends Error {
  constructor(
    readonly kind: "unavailable" | "refused" | "empty" | "unreadable",
    /** The provider's HTTP status, when it answered with an error. */
    readonly status?: number,
  ) {
    super(`study_assistant_${kind}`);
    this.name = "StudyAssistantError";
  }
}

/** The fewest usable items a study set is kept with. */
export const STUDY_SET_MINIMUM = { quiz: 3, flashcards: 4 } as const;

/** Statuses worth one more try: busy, or a passing server fault. */
const RETRYABLE = new Set([429, 500, 502, 503, 504]);

/** One earlier turn of the same chat. */
export interface StudyTurn {
  role: "student" | "assistant";
  text: string;
}

/** The most of a chat that is sent with a question; the caller trims it to
 * the plan's memory budget first. */
export const STUDY_HISTORY_MAX_TURNS = 400;
const STUDY_TURN_MAX_CHARS = 4_000;

/** Class material the student pointed the helper at, already fitted to the
 * plan's budget. */
export interface StudyReference {
  title: string;
  text: string;
}

/** A photo the student sent, as the scan cleared it. */
export interface StudyImage {
  bytes: Uint8Array;
  mediaType: string;
}

/** What a question is asked with, besides the chat. */
export interface AskExtras {
  /** Passages of class material, already chosen and fitted to the budget. */
  passages?: MaterialPassage[];
  /** Sources the student chose that could not be read. */
  unreadable?: UnreadableSource[];
  /** Photos the student attached. */
  images?: StudyImage[];
  learner?: LearnerProfile;
}

export interface StudyAssistant {
  /** [history] is the chat so far, oldest first, already fitted to the
   * plan's chat memory. */
  ask(
    question: string,
    history?: StudyTurn[],
    extras?: AskExtras,
  ): Promise<StudyAssistantReply>;
  /**
   * The writing on one scanned page, or the writing and a plain account of
   * one image, for the material index. Throws "unreadable" when there is
   * nothing to read.
   */
  transcribe(
    image: Uint8Array,
    mediaType: string,
    kind: "page" | "image",
  ): Promise<StudyAssistantReply>;
  /** Notes from a whiteboard photo. Throws "unreadable" for a blank one. */
  whiteboardNotes(
    image: Uint8Array,
    mediaType: string,
  ): Promise<StudyAssistantReply>;
  studySet(
    kind: StudySetKind,
    title: string,
    lessonText: string,
  ): Promise<StudySetResult>;
  /** Study notes made from a lesson's text (Studafy Plus). */
  lessonNotes(title: string, lessonText: string): Promise<StudyAssistantReply>;
  /**
   * A structured study notebook from labelled material (2026-10-07).
   * Throws "empty" when the reply is not a usable notebook.
   */
  notebook(
    title: string,
    passages: MaterialPassage[],
    extras?: { unreadable?: UnreadableSource[]; learner?: LearnerProfile },
  ): Promise<{ content: NotebookContent; usage?: StudyUsage }>;
}

type Message = { role: "system" | "user" | "assistant"; content: Content };

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
    notebookOutputTokens = 3_500,
    studySetOutputTokens = 1_400,
    notebookTimeoutMs = 120_000,
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
    earlier: Message[] = [],
    temperature = 0.3,
    timeLimitMs = timeoutMs,
  ): Promise<{ text: string; usage?: StudyUsage }> {
    const endpoint = new URL("/v1/chat/completions", allowed);
    // The allowlist, enforced rather than assumed: the origin that ends up
    // being called has to be the one that was configured.
    if (endpoint.origin !== allowed.origin) {
      throw new StudyAssistantError("refused");
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeLimitMs);
    const started = Date.now();
    try {
      const send = () =>
        fetchImpl(endpoint, {
          method: "POST",
          signal: controller.signal,
          headers: {
            authorization: `Bearer ${apiKey}`,
            "content-type": "application/json",
          },
          body: JSON.stringify({
            model,
            max_tokens: maxTokens,
            temperature,
            // Qwen3.5 thinks before answering by default, and the thinking
            // counts against max_tokens: a 600-token budget came back cut
            // off mid-sentence, or empty, after ~9s. Off, the same question
            // gets a complete answer in ~2s. A short explanation for a
            // student does not need a reasoning trace.
            reasoning: { enabled: false },
            messages: [
              { role: "system", content: system },
              ...earlier,
              { role: "user", content: user },
            ],
          }),
        });
      let response = await send();
      // One more try when the provider was briefly busy, while there is
      // time for it inside the request's own limit.
      if (
        RETRYABLE.has(response.status) &&
        Date.now() - started < timeLimitMs / 2
      ) {
        await response.body?.cancel().catch(() => {});
        await new Promise((resolve) => setTimeout(resolve, 600));
        response = await send();
      }
      if (!response.ok) {
        await response.body?.cancel().catch(() => {});
        throw new StudyAssistantError("unavailable", response.status);
      }
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
    async ask(
      question: string,
      history: StudyTurn[] = [],
      extras: AskExtras = {},
    ): Promise<StudyAssistantReply> {
      const passages = extras.passages ?? [];
      const unreadable = extras.unreadable ?? [];
      const images = extras.images ?? [];
      for (const image of images) {
        if (
          image.mediaType !== "image/jpeg" && image.mediaType !== "image/png"
        ) {
          throw new StudyAssistantError("refused");
        }
      }
      // The same redaction as the question, on both sides of the chat: a
      // reply can quote back what the student typed.
      const earlier: Message[] = history
        .slice(-STUDY_HISTORY_MAX_TURNS)
        .map((turn) => ({
          role: turn.role === "student" ? "user" : "assistant",
          content: redactForProvider(turn.text.slice(0, STUDY_TURN_MAX_CHARS)),
        }));
      // The material goes in the instructions, not as something the student
      // said: labelled, wrapped, and declared to be data, never orders.
      const grounded = passages.length > 0 || unreadable.length > 0;
      const system = [
        STUDY_PROMPTS.ask,
        learnerLine(extras.learner ?? {}),
        ...(grounded
          ? [GROUNDED_RULES, materialBlock(passages, unreadable)]
          : []),
      ].filter((part) => part.length > 0).join("\n\n");
      const user: Content = images.length === 0
        ? redactForProvider(question)
        : [
          { type: "text", text: redactForProvider(question) },
          ...images.map((image) => ({
            type: "image_url" as const,
            image_url: {
              url: `data:${image.mediaType};base64,${base64(image.bytes)}`,
            },
          })),
        ];
      const { text, usage } = await complete(
        system,
        user,
        images.length === 0 && !grounded
          ? maxOutputTokens
          : maxLongOutputTokens,
        earlier,
      );
      return { answer: text, ...(usage ? { usage } : {}) };
    },

    async transcribe(image, mediaType, kind): Promise<StudyAssistantReply> {
      if (mediaType !== "image/jpeg" && mediaType !== "image/png") {
        throw new StudyAssistantError("refused");
      }
      const { text, usage } = await complete(
        kind === "page"
          ? STUDY_PROMPTS.transcribePage
          : STUDY_PROMPTS.describeImage,
        [
          {
            type: "text",
            text: kind === "page"
              ? "Transcribe this page."
              : "Read this image.",
          },
          {
            type: "image_url",
            image_url: { url: `data:${mediaType};base64,${base64(image)}` },
          },
        ],
        maxLongOutputTokens,
        [],
        0,
      );
      if (isUnreadableReply(text)) {
        throw new StudyAssistantError("unreadable");
      }
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
        STUDY_PROMPTS.whiteboard,
        [
          { type: "text", text: "Make study notes from this whiteboard." },
          {
            type: "image_url",
            image_url: { url: `data:${mediaType};base64,${base64(image)}` },
          },
        ],
        maxLongOutputTokens,
      );
      if (isUnreadableReply(text)) {
        throw new StudyAssistantError("unreadable");
      }
      return { answer: text, ...(usage ? { usage } : {}) };
    },

    async lessonNotes(title, lessonText): Promise<StudyAssistantReply> {
      const { text, usage } = await complete(
        STUDY_PROMPTS.lessonNotes,
        lessonPrompt(title, lessonText),
        maxLongOutputTokens,
      );
      return { answer: text, ...(usage ? { usage } : {}) };
    },

    async notebook(title, passages, extras = {}) {
      const system = [
        NOTEBOOK_PROMPT,
        learnerLine(extras.learner ?? {}),
        materialBlock(passages, extras.unreadable ?? []),
      ].filter((part) => part.length > 0).join("\n\n");
      const { text, usage } = await complete(
        system,
        `Make the study notebook for the lesson: ${redactForProvider(title)}`,
        notebookOutputTokens,
        [],
        0.2,
        notebookTimeoutMs,
      );
      const content = parseNotebook(text, passages);
      if (!content) throw new StudyAssistantError("empty");
      return { content, ...(usage ? { usage } : {}) };
    },

    async studySet(kind, title, lessonText): Promise<StudySetResult> {
      const { text, usage } = await complete(
        STUDY_PROMPTS[kind],
        lessonPrompt(title, lessonText),
        studySetOutputTokens,
      );
      // Too few usable items is not a quiz: fail, and the hold is released,
      // rather than keep a one-question "quiz" for everyone.
      if (kind === "quiz") {
        const questions = parseQuiz(text);
        if (questions.length < STUDY_SET_MINIMUM.quiz) {
          throw new StudyAssistantError("empty");
        }
        return { kind, questions, ...(usage ? { usage } : {}) };
      }
      const cards = parseFlashcards(text);
      if (cards.length < STUDY_SET_MINIMUM.flashcards) {
        throw new StudyAssistantError("empty");
      }
      return { kind, cards, ...(usage ? { usage } : {}) };
    },
  };
}

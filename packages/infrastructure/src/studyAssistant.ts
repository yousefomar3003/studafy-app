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

import {
  type Flashcard,
  isUnreadableReply,
  lessonPrompt,
  parseFlashcards,
  parseQuiz,
  type QuizQuestion,
  redactForProvider,
  STUDY_PROMPTS,
  type StudySetKind,
  type StudyUsage,
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
  ) {
    super(`study_assistant_${kind}`);
    this.name = "StudyAssistantError";
  }
}

export interface StudyAssistant {
  ask(question: string): Promise<StudyAssistantReply>;
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
        STUDY_PROMPTS.ask,
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

    async studySet(kind, title, lessonText): Promise<StudySetResult> {
      const { text, usage } = await complete(
        STUDY_PROMPTS[kind],
        lessonPrompt(title, lessonText),
        maxLongOutputTokens,
      );
      if (kind === "quiz") {
        const questions = parseQuiz(text);
        if (questions.length === 0) throw new StudyAssistantError("empty");
        return { kind, questions, ...(usage ? { usage } : {}) };
      }
      const cards = parseFlashcards(text);
      if (cards.length === 0) throw new StudyAssistantError("empty");
      return { kind, cards, ...(usage ? { usage } : {}) };
    },
  };
}

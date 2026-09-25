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
  /** Hard ceiling on the reply, which is also the cost ceiling. */
  maxOutputTokens?: number;
  timeoutMs?: number;
  fetchImpl?: typeof fetch;
}

export interface StudyAssistantReply {
  answer: string;
}

export class StudyAssistantError extends Error {
  constructor(readonly kind: "unavailable" | "refused" | "empty") {
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
  "Explain clearly and briefly, at the level of the question.",
  "Help the student understand and practise; do not simply hand over answers",
  "to what is obviously graded homework - walk through the method instead.",
  "If a question is not about schoolwork, say so and stop.",
  "Never ask for personal details.",
].join(" ");

export interface StudyAssistant {
  ask(question: string): Promise<StudyAssistantReply>;
}

export function createStudyAssistant(
  options: StudyAssistantOptions,
): StudyAssistant {
  const {
    apiKey,
    baseUrl,
    model,
    maxOutputTokens = 600,
    timeoutMs = 20_000,
    fetchImpl = fetch,
  } = options;

  const allowed = new URL(baseUrl);
  if (allowed.protocol !== "https:") {
    throw new Error("study assistant base url must be https");
  }

  return {
    async ask(question: string): Promise<StudyAssistantReply> {
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
            max_tokens: maxOutputTokens,
            temperature: 0.3,
            messages: [
              { role: "system", content: SYSTEM_PROMPT },
              { role: "user", content: redactForProvider(question) },
            ],
          }),
        });
        if (!response.ok) throw new StudyAssistantError("unavailable");
        const body = await response.json() as {
          choices?: { message?: { content?: string } }[];
        };
        const answer = body.choices?.[0]?.message?.content?.trim();
        if (!answer) throw new StudyAssistantError("empty");
        return { answer };
      } catch (error) {
        if (error instanceof StudyAssistantError) throw error;
        throw new StudyAssistantError("unavailable");
      } finally {
        clearTimeout(timer);
      }
    },
  };
}

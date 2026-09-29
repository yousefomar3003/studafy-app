import { STUDY_LESSON_MAX_CHARS, type StudyUsage } from "@studafy/domain";
import type { RequestDbContext } from "../platform/dbContext";
import type { OutcomeTable } from "../platform/outcomes";
import type { StudyFeature, StudyRepository } from "./repository";

/**
 * Metering for every AI call (ADR-0029).
 *
 * A call is held at its worst-case cost against the student's allowance
 * before the provider is contacted, then settled to what the provider
 * reported, or released if nothing came back. The database refuses a hold
 * that would pass the plan's daily count or monthly cap, so a refused call
 * costs nothing.
 */

/** The model's prices, US dollars per million tokens. */
export interface ModelPrices {
  inputUsdPerMTok: number;
  outputUsdPerMTok: number;
}

/**
 * Worst-case input tokens per call, used to size the hold taken against a
 * student's cap before the provider is called. Generous on purpose: the hold
 * must never be smaller than what the call can cost, or the cap could be
 * passed. The actual cost replaces it as soon as the provider answers.
 */
const INPUT_BOUND_TOKENS = {
  ask: 1_200,
  // A full-resolution phone photo is ~15k image tokens on Qwen3.5.
  whiteboard: 16_000,
} as const;
const ASK_OUTPUT_TOKENS = 500;
const LONG_OUTPUT_TOKENS = 1_400;

/** Millionths of a dollar for this many tokens. */
export function costMicroUsd(
  prices: ModelPrices,
  inputTokens: number,
  outputTokens: number,
): number {
  // USD per million tokens is exactly micro-USD per token.
  return Math.ceil(
    inputTokens * prices.inputUsdPerMTok +
      outputTokens * prices.outputUsdPerMTok,
  );
}

export function holdFor(
  prices: ModelPrices,
  feature: StudyFeature,
  lessonChars = 0,
): number {
  switch (feature) {
    case "ask":
      // [lessonChars] is the chat history sent with a question. Two
      // characters a token is pessimistic for Arabic and English alike.
      return costMicroUsd(
        prices,
        INPUT_BOUND_TOKENS.ask + Math.ceil(lessonChars / 2),
        ASK_OUTPUT_TOKENS,
      );
    case "whiteboard":
      return costMicroUsd(
        prices,
        INPUT_BOUND_TOKENS.whiteboard,
        LONG_OUTPUT_TOKENS,
      );
    default: {
      // Roughly three characters a token, plus the instructions.
      const input = Math.ceil(
        Math.min(lessonChars, STUDY_LESSON_MAX_CHARS) / 3,
      ) + 600;
      return costMicroUsd(prices, input, LONG_OUTPUT_TOKENS);
    }
  }
}

/** The refusals an AI call can meet before anything is spent. */
export const AI_REFUSALS: OutcomeTable = {
  plan_required: ["PLAN_REQUIRED", 403],
  monthly_cap: ["AI_ALLOWANCE_USED", 429],
  daily_limit: ["AI_DAILY_LIMIT", 429],
};

export type MeteredResult<T> =
  | { ok: true; value: T }
  | { ok: false; outcome: string };

/** Runs provider calls against the AI ledger. */
export class AiMeter {
  constructor(
    private readonly repository: StudyRepository,
    private readonly prices: ModelPrices,
  ) {}

  /**
   * Holds [hold], runs [call], then settles to what the provider reported -
   * or releases the hold if the call threw. Returns the ledger's outcome when
   * the hold was refused.
   */
  async run<T extends { usage?: StudyUsage }>(
    context: RequestDbContext,
    feature: StudyFeature,
    hold: number,
    call: () => Promise<T>,
  ): Promise<MeteredResult<T>> {
    const reserved = await this.repository.usage(context, "reserve", {
      feature,
      estimateMicroUsd: hold,
    });
    if (reserved["outcome"] !== "ok") {
      return { ok: false, outcome: String(reserved["outcome"]) };
    }
    const usageId = reserved["usageId"];
    let value: T;
    try {
      value = await call();
    } catch (error) {
      await this.repository.usage(context, "release", { usageId });
      throw error;
    }
    const usage = value.usage;
    await this.repository.usage(context, "settle", {
      usageId,
      // No usage reported: charge the hold, which is the upper bound.
      costMicroUsd: usage
        ? costMicroUsd(this.prices, usage.inputTokens, usage.outputTokens)
        : hold,
      inputTokens: usage?.inputTokens ?? null,
      outputTokens: usage?.outputTokens ?? null,
      model: usage?.model ?? null,
    });
    return { ok: true, value };
  }
}

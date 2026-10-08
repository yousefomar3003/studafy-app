import { type StudyUsage, tokenBound } from "@studafy/domain";
import type { RequestDbContext } from "../platform/dbContext";
import type { OutcomeTable } from "../platform/outcomes";
import type { StudyFeature, StudyRepository } from "./repository";

/**
 * Metering for every AI call (ADR-0029, ADR-0037).
 *
 * A call is held at its worst case - in tokens against the student's
 * allowance, and in dollars against the paid plans' cap underneath - before
 * the provider is contacted, then settled to the tokens the provider
 * reported, or released if nothing came back. The database refuses a hold
 * that would pass either, under a per-student lock, so concurrent requests
 * cannot overspend and a refused call costs nothing.
 */

/** The model's prices, US dollars per million tokens. */
export interface ModelPrices {
  inputUsdPerMTok: number;
  outputUsdPerMTok: number;
}

/** What a call is held at before it runs. */
export interface Hold {
  /** Worst-case input plus output tokens. */
  tokens: number;
  /** The same, priced. */
  microUsd: number;
}

/** The longest reply each kind of call may have: its output bound. */
export const OUTPUT_TOKENS = {
  /** A plain question. */
  ask: 600,
  /** A question with class material or a photo, notes, quizzes. */
  long: 1_400,
} as const;

/** A full-resolution phone photo is ~15k image tokens on Qwen3.5. */
export const PHOTO_INPUT_TOKENS = 16_000;
/** The instructions sent with every call. */
const INSTRUCTION_TOKENS = 700;

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

/** A hold for [inputChars] of text, [photos] photos and [outputTokens]. */
export function holdFor(
  prices: ModelPrices,
  inputChars: number,
  outputTokens: number,
  photos = 0,
): Hold {
  const input = INSTRUCTION_TOKENS + tokenBound(inputChars) +
    photos * PHOTO_INPUT_TOKENS;
  return {
    tokens: input + outputTokens,
    microUsd: costMicroUsd(prices, input, outputTokens),
  };
}

/** The refusals an AI call can meet before anything is spent. */
export const AI_REFUSALS: OutcomeTable = {
  plan_required: ["PLAN_REQUIRED", 403],
  allowance_exhausted: ["AI_ALLOWANCE_USED", 429],
  monthly_cap: ["AI_ALLOWANCE_USED", 429],
  in_progress: ["AI_REQUEST_IN_PROGRESS", 409],
  duplicate: ["AI_REQUEST_IN_PROGRESS", 409],
};

export interface Allowance {
  period: "week" | "month";
  total: number;
  used: number;
  remaining: number;
  resetsAt: string;
}

export function allowanceOf(value: unknown): Allowance | null {
  if (!value || typeof value !== "object") return null;
  const v = value as Record<string, unknown>;
  return {
    period: v["period"] === "week" ? "week" : "month",
    total: Number(v["total"] ?? 0),
    used: Number(v["used"] ?? 0),
    remaining: Number(v["remaining"] ?? 0),
    resetsAt: new Date(String(v["resetsAt"])).toISOString(),
  };
}

export type MeteredResult<T> =
  | { ok: true; value: T; allowance: Allowance | null }
  | { ok: false; outcome: string; allowance: Allowance | null };

/** Runs provider calls against the AI ledger. */
export class AiMeter {
  constructor(
    private readonly repository: StudyRepository,
    private readonly prices: ModelPrices,
  ) {}

  /**
   * Holds [hold], runs [call], then settles to what the provider reported -
   * or releases the hold if the call threw. [requestKey] makes a retry of
   * the same request free, and refuses one still running.
   */
  async run<T extends { usage?: StudyUsage }>(
    context: RequestDbContext,
    feature: StudyFeature,
    hold: Hold,
    call: () => Promise<T>,
    requestKey?: string,
  ): Promise<MeteredResult<T>> {
    const reserved = await this.repository.usage(context, "reserve", {
      feature,
      estimateMicroUsd: hold.microUsd,
      estimateTokens: hold.tokens,
      ...(requestKey ? { requestKey } : {}),
    });
    if (reserved["outcome"] !== "ok") {
      return {
        ok: false,
        outcome: String(reserved["outcome"]),
        allowance: allowanceOf(reserved["allowance"]),
      };
    }
    const usageId = reserved["usageId"];
    let value: T;
    try {
      value = await call();
    } catch (error) {
      // A reply the provider produced but that could not be used, or a
      // request that timed out after it was sent, was still paid for:
      // releasing it made such failures free to repeat without limit
      // (security audit 2026-10-08). It is settled to what the provider
      // reported, or to the hold when it reported nothing. Only a call
      // that never reached the provider, or that it refused, is released.
      const failed = error as { billed?: unknown; usage?: StudyUsage };
      if (failed?.billed === true) {
        await this.repository.usage(context, "settle", {
          usageId,
          costMicroUsd: failed.usage
            ? costMicroUsd(
              this.prices,
              failed.usage.inputTokens,
              failed.usage.outputTokens,
            )
            : hold.microUsd,
          inputTokens: failed.usage?.inputTokens ?? null,
          outputTokens: failed.usage?.outputTokens ?? null,
          model: failed.usage?.model ?? null,
        });
      } else {
        await this.repository.usage(context, "release", { usageId });
      }
      throw error;
    }
    const usage = value.usage;
    const settled = await this.repository.usage(context, "settle", {
      usageId,
      // No usage reported: the database charges the hold, the upper bound.
      costMicroUsd: usage
        ? costMicroUsd(this.prices, usage.inputTokens, usage.outputTokens)
        : hold.microUsd,
      inputTokens: usage?.inputTokens ?? null,
      outputTokens: usage?.outputTokens ?? null,
      model: usage?.model ?? null,
    });
    return { ok: true, value, allowance: allowanceOf(settled["allowance"]) };
  }
}

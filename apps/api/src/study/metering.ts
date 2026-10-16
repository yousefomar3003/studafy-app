import type { OutcomeTable } from "../platform/outcomes";
import { AI_ACCESS_REFUSALS } from "./aiAccess";

/**
 * Metering for every AI call (ADR-0029, ADR-0037). The meter itself lives
 * in @studafy/infrastructure, shared with the worker that writes study
 * notebooks (2026-10-16); what the API adds is how a refusal is answered.
 */
export {
  AiMeter,
  type Allowance,
  allowanceOf,
  costMicroUsd,
  type Hold,
  holdFor,
  type MeteredResult,
  type ModelPrices,
  OUTPUT_TOKENS,
  PHOTO_INPUT_TOKENS,
} from "@studafy/infrastructure";

/** The refusals an AI call can meet before anything is spent. */
export const AI_REFUSALS: OutcomeTable = {
  // Not a student in a class, or no current AI consent (ADR-0043): the
  // ledger's own check, under the routes' AI gate.
  ...AI_ACCESS_REFUSALS,
  plan_required: ["PLAN_REQUIRED", 403],
  allowance_exhausted: ["AI_ALLOWANCE_USED", 429],
  monthly_cap: ["AI_ALLOWANCE_USED", 429],
  in_progress: ["AI_REQUEST_IN_PROGRESS", 409],
  duplicate: ["AI_REQUEST_IN_PROGRESS", 409],
};

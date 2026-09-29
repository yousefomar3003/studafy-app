/**
 * How much of a chat the study helper remembers (2026-09-28).
 *
 * Each question carries the newest turns of its chat that fit the plan's
 * memory budget, whole turns only, oldest dropped first. The budget is in
 * tokens and never exceeds the model's context window, less what the
 * instructions, the question and the answer need.
 *
 * Tokens are counted as two characters each: pessimistic for English (about
 * four) and about right for Arabic, so the budget - and the cost hold sized
 * the same way - is never exceeded in either language.
 */

export const CHARS_PER_TOKEN = 2;

/** Room kept in the window for the instructions, the question and the answer. */
export const CONTEXT_RESERVE_TOKENS = 4_096;

export interface ChatMemoryBudgets {
  contextWindowTokens: number;
  freeTokens: number;
  paidTokens: number;
}

/** The plan's budget in tokens, inside the model's window. */
export function chatMemoryTokens(
  budgets: ChatMemoryBudgets,
  plan: string,
): number {
  const planned = plan === "plus" || plan === "max"
    ? budgets.paidTokens
    : budgets.freeTokens;
  const window = Math.max(
    0,
    budgets.contextWindowTokens - CONTEXT_RESERVE_TOKENS,
  );
  return Math.max(0, Math.min(planned, window));
}

/** The newest whole turns whose text fits [budgetTokens], in order. */
export function fitChatMemory<T extends { text: string }>(
  turns: readonly T[],
  budgetTokens: number,
): T[] {
  const budgetChars = budgetTokens * CHARS_PER_TOKEN;
  let used = 0;
  let start = turns.length;
  while (start > 0) {
    const next = turns[start - 1]!.text.length;
    if (used + next > budgetChars) break;
    used += next;
    start--;
  }
  return turns.slice(start);
}

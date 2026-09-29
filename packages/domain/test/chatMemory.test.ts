import { describe, expect, test } from "bun:test";
import {
  chatMemoryTokens,
  CONTEXT_RESERVE_TOKENS,
  fitChatMemory,
} from "../src";

describe("how much of a chat the helper remembers", () => {
  const budgets = {
    contextWindowTokens: 262_144,
    freeTokens: 4_000,
    paidTokens: 32_000,
  };

  test("each plan has its budget", () => {
    expect(chatMemoryTokens(budgets, "free")).toBe(4_000);
    expect(chatMemoryTokens(budgets, "plus")).toBe(32_000);
    expect(chatMemoryTokens(budgets, "max")).toBe(32_000);
    expect(chatMemoryTokens(budgets, "anything else")).toBe(4_000);
  });

  test("no budget ever passes the model's context window", () => {
    const huge = { ...budgets, paidTokens: 10_000_000 };
    expect(chatMemoryTokens(huge, "max")).toBe(
      262_144 - CONTEXT_RESERVE_TOKENS,
    );
  });

  test("the newest whole turns that fit are kept, in order", () => {
    const turns = ["aaaa", "bbbb", "cccc", "dddd"].map((text) => ({ text }));
    // Four tokens is eight characters at two a token: the last two turns.
    expect(fitChatMemory(turns, 4).map((t) => t.text)).toEqual([
      "cccc",
      "dddd",
    ]);
    expect(fitChatMemory(turns, 100)).toHaveLength(4);
    expect(fitChatMemory(turns, 0)).toEqual([]);
  });

  test("a turn is never cut in half", () => {
    const turns = [{ text: "x".repeat(10) }, { text: "y".repeat(3) }];
    expect(fitChatMemory(turns, 3).map((t) => t.text)).toEqual(["yyy"]);
  });
});

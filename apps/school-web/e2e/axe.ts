import AxeBuilder from "@axe-core/playwright";
import { expect, type Page } from "@playwright/test";

/**
 * WCAG 2.1 A and AA checks on what the page shows now (plan 4.7). Serious
 * and critical problems fail the test; each is listed with the elements it
 * found, so the report says what to fix. The public pages fade sections in
 * as they scroll into view, so their scans run with reduced motion (every
 * section shown), as the site project in playwright.config.ts sets.
 */
export async function expectAccessible(page: Page, where: string) {
  const { violations } = await new AxeBuilder({ page })
    .withTags(["wcag2a", "wcag2aa", "wcag21a", "wcag21aa"])
    .analyze();
  const blocking = violations
    .filter((v) => v.impact === "serious" || v.impact === "critical")
    .map((v) => ({
      rule: v.id,
      help: v.help,
      nodes: v.nodes.slice(0, 5).map((n) => n.target.join(" ")),
    }));
  expect(blocking, `accessibility problems on ${where}`).toEqual([]);
}

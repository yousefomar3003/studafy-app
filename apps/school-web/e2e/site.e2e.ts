import { expect, test } from "@playwright/test";
import { expectAccessible } from "./axe";

// The public pages as built, with the portal switch off (the default).
const PAGES = ["/", "/features", "/about", "/contact"];

for (const lang of ["en", "ar"] as const) {
  for (const path of PAGES) {
    const url = lang === "en" ? path : path === "/" ? "/ar" : `/ar${path}`;

    test(`${url} is prerendered, in its language, and accessible`, async ({ page }) => {
      const response = await page.goto(url);
      expect(response?.status()).toBe(200);
      await expect(page.locator("html")).toHaveAttribute("lang", lang);
      await expect(page.locator("html")).toHaveAttribute(
        "dir",
        lang === "ar" ? "rtl" : "ltr",
      );
      await expect(page.locator("h1")).toHaveCount(1);
      // With the portal switch off, nothing points at the portal.
      await expect(page.locator('a[href*="/schools"]')).toHaveCount(0);
      await expect(page.locator('a[href*="school.studafy.com"]')).toHaveCount(
        0,
      );
      await expectAccessible(page, url);
    });
  }
}

test("every link on the home page leads to a page that exists", async ({ page, request }) => {
  await page.goto("/");
  const hrefs = await page.locator("a[href^='/']").evaluateAll((
    links,
  ) => [...new Set(links.map((a) => (a as HTMLAnchorElement).pathname))]);
  expect(hrefs.length).toBeGreaterThan(3);
  for (const href of hrefs) {
    expect((await request.get(href)).status(), href).toBe(200);
  }
});

test("the language switch goes to the same page in Arabic", async ({ page }) => {
  await page.goto("/features");
  await page.locator("[data-lang-switch='ar']").first().click();
  await expect(page).toHaveURL(/\/ar\/features$/);
  await expect(page.locator("html")).toHaveAttribute("dir", "rtl");
});

test("a missing page says so, in both languages", async ({ page }) => {
  for (
    const [path, lang] of [["/no-such-page", "en"], ["/ar/no-such-page", "ar"]]
  ) {
    const response = await page.goto(path);
    expect(response?.status()).toBe(404);
    await expect(page.locator("html")).toHaveAttribute("lang", lang!);
    await expect(page.locator("h1")).toBeVisible();
    await expectAccessible(page, path!);
  }
});

test("with reduced motion, nothing animates", async ({ browser }) => {
  const context = await browser.newContext({ reducedMotion: "reduce" });
  const page = await context.newPage();
  await page.goto("/");
  await page.mouse.wheel(0, 2000);
  const running = await page.evaluate(() =>
    document.getAnimations().filter((a) => a.playState === "running").length
  );
  expect(running).toBe(0);
  await context.close();
});

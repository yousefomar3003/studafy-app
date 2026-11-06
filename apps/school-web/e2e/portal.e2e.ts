import { expect, type Page, test } from "@playwright/test";
import { expectAccessible } from "./axe";

// The School Portal in demo mode (src/portal/demo.ts): one school, two
// classes, invented students. The data is fixed, so the tests can name it.
const ORG = "d0000000-0000-4000-8000-000000000001";
const CLASS = "d0000000-0000-4000-8000-000000000101";
const at = (path: string) => `/portal/o/${ORG}${path}`;

async function open(page: Page, path: string, heading: string | RegExp) {
  await page.goto(at(path));
  await expect(page.locator("main h1").first()).toHaveText(heading);
}

test.beforeEach(async ({ page }) => {
  // English unless a test switches; the choice is kept in the browser.
  await page.addInitScript(() => {
    if (!sessionStorage.getItem("e2e")) {
      localStorage.setItem("studafy.portal.lang", "en");
      sessionStorage.setItem("e2e", "1");
    }
  });
});

test("signed in, the portal opens on the school's dashboard", async ({ page }) => {
  await page.goto("/portal/");
  await expect(page).toHaveURL(new RegExp(`/portal/o/${ORG}$`));
  await expect(page.locator("main h1").first()).toHaveText("Dashboard");
  await expect(page.getByText("Cedar Grove").first()).toBeVisible();
  await expectAccessible(page, "dashboard");
});

test("classes list the term and last activity, and open on the overview", async ({ page }) => {
  await open(page, "/classes", "Classes");
  const row = page.locator("tr", { hasText: "Grade 7 Science" });
  await expect(row).toContainText("Term 1");
  await expectAccessible(page, "classes");
  await row.getByRole("link", { name: "Grade 7 Science" }).click();
  await expect(page).toHaveURL(new RegExp(`/classes/${CLASS}/overview$`));
  await expect(page.getByText("Attendance this month")).toBeVisible();
  await expect(page.getByRole("link", { name: "Essay on rivers" }))
    .toBeVisible();
  await expect(page.getByText("Read-only.")).toBeVisible();
  await expectAccessible(page, "class overview");
});

for (
  const [tab, sees] of [
    ["students", "@"],
    ["lessons", ""],
    ["assignments", "Essay on rivers"],
    ["tests", ""],
    ["marks", ""],
    ["attendance", ""],
    ["wellbeing", ""],
  ] as const
) {
  test(`a class's ${tab} tab loads and is accessible`, async ({ page }) => {
    await page.goto(at(`/classes/${CLASS}/${tab}`));
    await expect(page.locator(`.tabs a[aria-current="page"]`)).toHaveAttribute(
      "href",
      new RegExp(`/${tab}$`),
    );
    await expect(page.locator(".state[role=status]")).toHaveCount(0);
    if (sees) await expect(page.locator("main")).toContainText(sees);
    await expectAccessible(page, `class ${tab}`);
  });
}

test("an assignment opens every student's hand-in", async ({ page }) => {
  await page.goto(at(`/classes/${CLASS}/assignments`));
  await page.getByRole("link", { name: /Essay on rivers|View hand-ins/ })
    .first().click();
  await expect(page).toHaveURL(/\/assignments\/[0-9a-f-]{36}$/);
  await expect(page.locator("main")).toContainText("Hand-ins");
  await expectAccessible(page, "hand-ins");
});

for (
  const [path, heading] of [
    ["/teachers", "Teachers"],
    ["/reports", "Reports"],
    ["/announcements", "Announcements"],
    ["/groups", /Class groups/],
    ["/settings", "Settings"],
  ] as const
) {
  test(`${path} loads and is accessible`, async ({ page }) => {
    await open(page, path, heading);
    await expectAccessible(page, path);
  });
}

test("a pending invitation can be corrected without a free seat", async ({ page }) => {
  await open(page, "/settings", "Settings");
  const invite = page.locator("li", { hasText: "deputy@cedar.example" });
  await invite.getByRole("button", { name: "Edit" }).click();
  await expect(page.getByRole("heading", { name: "Edit the invitation" }))
    .toBeVisible();
  await expect(page.getByLabel("Their email address")).toHaveValue(
    "deputy@cedar.example",
  );
  await expect(page.getByLabel("Their email address")).toHaveAttribute(
    "readonly",
    "",
  );
  await page.getByLabel("Their job title").fill("Deputy principal");
  await page.getByRole("button", { name: "Send again" }).click();
  await expect(page.locator(".notice.good")).toContainText("Invitation sent");
});

test("cancelling an invitation asks first", async ({ page }) => {
  await open(page, "/settings", "Settings");
  await page.locator("li", { hasText: "deputy@cedar.example" })
    .getByRole("button", { name: "Cancel invitation" }).click();
  const dialog = page.getByRole("dialog");
  await expect(dialog).toContainText("Cancel this invitation?");
  await expectAccessible(page, "cancel invitation dialog");
  await dialog.getByRole("button", { name: "Cancel invitation" }).click();
  await expect(page.locator(".notice.good")).toContainText(
    "Invitation cancelled",
  );
});

test("in Arabic the portal reads right to left, and stays accessible", async ({ page }) => {
  await open(page, `/classes/${CLASS}/overview`, "Grade 7 Science");
  await page.getByRole("button", { name: "العربية" }).click();
  await expect(page.locator("html")).toHaveAttribute("dir", "rtl");
  await expect(page.locator("html")).toHaveAttribute("lang", "ar");
  await expect(page.getByText("الحضور هذا الشهر")).toBeVisible();
  await expectAccessible(page, "class overview in Arabic");
});

test("an address that is not a page goes back to the school's own dashboard", async ({ page }) => {
  await page.goto("/portal/o/not-an-id/classes");
  await expect(page).toHaveURL(new RegExp(`/portal/o/${ORG}$`));
  await expect(page.locator("main h1").first()).toHaveText("Dashboard");
});

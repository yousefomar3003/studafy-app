import { defineConfig, devices } from "@playwright/test";

/**
 * Browser tests (plan 10): the public pages as built (prerendered, served
 * as Vercel serves them, e2e/serve.ts), and the School Portal clicked through in demo mode on the
 * dev server (invented data, no sign-in, no API; demo mode exists only on
 * the dev server). Each page also gets an accessibility scan (axe).
 *
 * Files are named *.e2e.ts so `bun test` never picks them up.
 * Run: `bun run e2e` in apps/school-web (needs `bunx playwright install
 * chromium` once).
 */
const SITE = 5180;
const PORTAL = 5179;

export default defineConfig({
  testDir: "e2e",
  testMatch: "**/*.e2e.ts",
  fullyParallel: true,
  forbidOnly: !!process.env["CI"],
  retries: process.env["CI"] ? 1 : 0,
  reporter: process.env["CI"] ? [["list"], ["github"]] : "list",
  use: { trace: "retain-on-failure" },
  projects: [
    {
      name: "site",
      testMatch: "**/site.e2e.ts",
      use: {
        ...devices["Desktop Chrome"],
        baseURL: `http://127.0.0.1:${SITE}`,
        // Sections fade in as they scroll into view; off, the scan sees all.
        reducedMotion: "reduce",
      },
    },
    {
      name: "portal",
      testMatch: "**/portal.e2e.ts",
      use: {
        ...devices["Desktop Chrome"],
        baseURL: `http://127.0.0.1:${PORTAL}`,
      },
    },
    {
      name: "portal-phone",
      testMatch: "**/portal.e2e.ts",
      use: { ...devices["Pixel 7"], baseURL: `http://127.0.0.1:${PORTAL}` },
    },
  ],
  webServer: [
    {
      // The site as it is deployed: build, then serve dist/ as Vercel does.
      command: `bun run build && bun e2e/serve.ts ${SITE}`,
      url: `http://127.0.0.1:${SITE}/`,
      reuseExistingServer: !process.env["CI"],
      timeout: 180_000,
    },
    {
      command: `bunx vite --host 127.0.0.1 --port ${PORTAL} --strictPort`,
      url: `http://127.0.0.1:${PORTAL}/portal/`,
      env: { VITE_PORTAL_DEMO: "true" },
      reuseExistingServer: !process.env["CI"],
      timeout: 60_000,
    },
  ],
});

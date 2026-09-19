import type { Context } from "hono";

/**
 * Integration harnesses model an MFA-verified session by default, because
 * privileged routes require AAL2 (audit H3). A test proving the AAL1 denial
 * sends `x-test-aal: aal1`.
 */
export function testAssurance(c: Context): "aal1" | "aal2" {
  return c.req.header("x-test-aal") === "aal1" ? "aal1" : "aal2";
}

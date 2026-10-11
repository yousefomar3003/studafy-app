import { expect, test } from "bun:test";
import { hostedWorkerEnvironment } from "./start-hosted-worker";

const env = {
  ENVIRONMENT: "development",
  SUPABASE_URL: "https://projectref.supabase.co",
  DATABASE_URL:
    "postgres://postgres:synthetic@db.projectref.supabase.co/postgres",
  API_CURSOR_SIGNING_KEY: "synthetic",
  RATE_LIMIT_HMAC_SIGNING_KEY: "synthetic-rate",
  CLASS_JOIN_CODE_KEY: "synthetic-join",
  FILE051_SCAN_ENABLED: "true",
};

test("hosted worker refuses to start without the upload scan", () => {
  expect(() => hostedWorkerEnvironment({ ...env, FILE051_SCAN_ENABLED: "" }))
    .toThrow("FILE051_SCAN_ENABLED");
});

test("hosted worker keeps the same project checks as the hosted API", () => {
  expect(() =>
    hostedWorkerEnvironment({
      ...env,
      DATABASE_URL: "postgres://postgres:synthetic@127.0.0.1:54322/postgres",
    })
  ).toThrow();
});

test("hosted worker runs files and notifications, nothing else", () => {
  const result = hostedWorkerEnvironment({
    ...env,
    DB_HOUSEKEEPING_ENABLED: "true",
    PAY071_BILLING_ENABLED: "true",
  });
  expect(result.FILE051_SCAN_ENABLED).toBe("true");
  expect(result.DB_HOUSEKEEPING_ENABLED).toBe("false");
  expect(result.PAY071_BILLING_ENABLED).toBe("false");
});

test("in-app notifications are delivered unless the file turns them off", () => {
  expect(hostedWorkerEnvironment(env).OPS061_NOTIFICATIONS_ENABLED)
    .toBe("true");
  expect(
    hostedWorkerEnvironment({ ...env, OPS061_NOTIFICATIONS_ENABLED: "false" })
      .OPS061_NOTIFICATIONS_ENABLED,
  ).toBe("false");
});

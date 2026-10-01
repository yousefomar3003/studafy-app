import { expect, test } from "bun:test";
import { validateHostedEnvironment } from "./start-hosted-api";
const env = {
  ENVIRONMENT: "development",
  SUPABASE_URL: "https://projectref.supabase.co",
  API_CURSOR_SIGNING_KEY: "synthetic",
  RATE_LIMIT_HMAC_SIGNING_KEY: "synthetic-rate",
  CLASS_JOIN_CODE_KEY: "synthetic-join",
};
test("hosted launcher refuses absent, placeholder, local and cross-project database URLs", () => {
  for (
    const DATABASE_URL of [
      "",
      "postgres://postgres:[YOUR-PASSWORD]@db.projectref.supabase.co/postgres",
      "postgres://postgres:synthetic@127.0.0.1:54322/postgres",
      "postgres://postgres:synthetic@db.other.supabase.co/postgres",
      "postgres://postgres.other:synthetic@aws-0-region.pooler.supabase.com/postgres",
    ]
  ) {
    expect(() => validateHostedEnvironment({ ...env, DATABASE_URL })).toThrow();
  }
});
test("hosted launcher accepts only the matching direct or pooler project", () => {
  for (
    const DATABASE_URL of [
      "postgres://postgres:synthetic@db.projectref.supabase.co/postgres",
      "postgres://postgres.projectref:synthetic@aws-0-region.pooler.supabase.com/postgres",
    ]
  ) {
    expect(() => validateHostedEnvironment({ ...env, DATABASE_URL })).not
      .toThrow();
  }
});

test("hosted launcher refuses to run without its own class code key", () => {
  const DATABASE_URL =
    "postgres://postgres:synthetic@db.projectref.supabase.co/postgres";
  expect(() =>
    validateHostedEnvironment({ ...env, DATABASE_URL, CLASS_JOIN_CODE_KEY: "" })
  ).toThrow("CLASS_JOIN_CODE_KEY");
  expect(() =>
    validateHostedEnvironment({
      ...env,
      DATABASE_URL,
      CLASS_JOIN_CODE_KEY: env.API_CURSOR_SIGNING_KEY,
    })
  ).toThrow("CLASS_JOIN_CODE_KEY");
});

import { describe, expect, test } from "bun:test";
import { databaseTls } from "../src/index";

describe("database TLS (security audit 2026-10-08)", () => {
  test("a remote host is encrypted by default", () => {
    expect(
      databaseTls(
        "postgresql://postgres.ref:pw@aws-0-eu-central-1.pooler.supabase.com:6543/postgres",
      ),
    ).toBe("require");
  });

  test("with the CA, the certificate is verified too", () => {
    expect(
      databaseTls("postgresql://u:p@db.example.com:5432/postgres", "PEM"),
    ).toEqual({ ca: "PEM", rejectUnauthorized: true });
  });

  test("the local stack stays plaintext", () => {
    expect(
      databaseTls("postgresql://postgres:postgres@127.0.0.1:54322/postgres"),
    ).toBe(false);
    expect(databaseTls("postgresql://u:p@localhost/postgres")).toBe(false);
  });

  test("an explicit sslmode in the URL is left to the driver", () => {
    expect(
      databaseTls(
        "postgresql://u:p@db.example.com/postgres?sslmode=verify-full",
      ),
    ).toBeUndefined();
  });
});

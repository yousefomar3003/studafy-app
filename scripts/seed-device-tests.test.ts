import { describe, expect, test } from "bun:test";
import { buildPng, DEVICE_SCHOOL, requireLocalUrl } from "./seed-device-tests";

describe("seed-device-tests", () => {
  test("accepts only this machine", () => {
    expect(requireLocalUrl("X", "http://127.0.0.1:54321").port).toBe("54321");
    expect(requireLocalUrl("X", "http://localhost:8090").hostname).toBe(
      "localhost",
    );
    expect(
      requireLocalUrl("X", "postgresql://postgres:postgres@127.0.0.1:54322/db")
        .hostname,
    ).toBe("127.0.0.1");
    for (
      const remote of [
        "https://abcdefghijklmnop.supabase.co",
        "postgresql://u:p@db.abcdefghijklmnop.supabase.co:5432/postgres",
        "postgresql://u:p@aws-0-eu-central-1.pooler.supabase.com:6543/postgres",
        "http://192.168.1.109:8080",
        "http://127.0.0.1.example.com",
      ]
    ) {
      expect(() => requireLocalUrl("X", remote)).toThrow(/Refusing to run/);
    }
    expect(() => requireLocalUrl("X", undefined)).toThrow(/not set/);
    expect(() => requireLocalUrl("X", "not a url")).toThrow(/not a URL/);
  });

  test("uses the ids and accounts the exam test names", () => {
    expect(DEVICE_SCHOOL.schoolId).toBe("7e570000-0000-4000-8000-0000000000b1");
    expect(DEVICE_SCHOOL.examClassId).toBe(
      "7e570000-0000-4000-8000-0000000000d1",
    );
    expect(DEVICE_SCHOOL.devStudentId).toBe(
      "7e570000-0000-4000-8000-0000000000e1",
    );
    for (const user of Object.values(DEVICE_SCHOOL.users)) {
      expect(user.email).toEndWith("@synthetic.studafy.test");
    }
  });

  test("builds a PNG", () => {
    const png = buildPng();
    expect([...png.subarray(0, 8)]).toEqual([
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);
    expect(
      new TextDecoder().decode(png.subarray(png.length - 8, png.length - 4)),
    )
      .toBe("IEND");
  });
});

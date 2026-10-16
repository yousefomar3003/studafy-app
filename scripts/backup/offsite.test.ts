import { describe, expect, test } from "bun:test";
import {
  locationProblem,
  objectKey,
  OffsiteConfigError,
  readOffsiteSettings,
} from "./offsite";

const r2 = {
  BACKUP_OFFSITE_ENDPOINT: "https://0123abcd.eu.r2.cloudflarestorage.com",
  BACKUP_OFFSITE_BUCKET: "studafy-backups",
  BACKUP_OFFSITE_ACCESS_KEY_ID: "synthetic-access-key",
  BACKUP_OFFSITE_SECRET_ACCESS_KEY: "synthetic-secret",
  BACKUP_OFFSITE_REGION: "auto",
};

describe("off-site backup settings", () => {
  test("nothing set means not configured (artifact fallback)", () => {
    expect(readOffsiteSettings({})).toEqual({ configured: false });
    expect(readOffsiteSettings({ BACKUP_OFFSITE_BUCKET: " " })).toEqual({
      configured: false,
    });
  });

  test("all five set is configured, with the default prefix", () => {
    const settings = readOffsiteSettings(r2);
    expect(settings.configured).toBe(true);
    if (settings.configured) {
      expect(settings.config.prefix).toBe("studafy/");
      expect(settings.config.region).toBe("auto");
    }
  });

  test("half configured is an error, never a silent fallback", () => {
    const { BACKUP_OFFSITE_REGION: _, ...noRegion } = r2;
    expect(() => readOffsiteSettings(noRegion)).toThrow(
      /missing: BACKUP_OFFSITE_REGION/,
    );
  });

  test("a bad prefix is refused", () => {
    for (const prefix of ["../x/", "/abs/", "no-slash"]) {
      expect(() =>
        readOffsiteSettings({ ...r2, BACKUP_OFFSITE_PREFIX: prefix })
      ).toThrow(OffsiteConfigError);
    }
  });
});

describe("off-site location", () => {
  test("R2 must be an EU-jurisdiction bucket", () => {
    expect(locationProblem(r2.BACKUP_OFFSITE_ENDPOINT, "auto")).toBeNull();
    expect(
      locationProblem("https://0123abcd.r2.cloudflarestorage.com", "auto"),
    ).toMatch(/EU jurisdiction/);
  });

  test("AWS must be an eu-* region", () => {
    expect(
      locationProblem("https://s3.eu-central-1.amazonaws.com", "eu-central-1"),
    ).toBeNull();
    expect(
      locationProblem("https://s3.il-central-1.amazonaws.com", "il-central-1"),
    ).toMatch(/outside the EU/);
  });

  test("the region is required explicitly", () => {
    expect(locationProblem(r2.BACKUP_OFFSITE_ENDPOINT, "")).toMatch(
      /set explicitly/,
    );
  });

  test("https only, except a loopback test server", () => {
    expect(locationProblem("http://storage.example.com", "auto")).toMatch(
      /https/,
    );
    expect(locationProblem("http://127.0.0.1:56390", "auto")).toBeNull();
    expect(
      locationProblem("https://user:pw@storage.example.com", "auto"),
    ).toMatch(/bare/);
  });

  test("object keys are the prefix plus a plain file name", () => {
    expect(objectKey("studafy/", "studafy-backup-1.tar.age")).toBe(
      "studafy/studafy-backup-1.tar.age",
    );
    expect(() => objectKey("studafy/", "../evil")).toThrow(OffsiteConfigError);
  });
});

import { describe, expect, test } from "bun:test";
import { SupabasePrivateFileStorage } from "@studafy/infrastructure";

const enabled = process.env.FILE050_STORAGE_INTEGRATION === "true";
const origin = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

describe.skipIf(!enabled)("FILE-050 local Storage integration", () => {
  test("the signed capability is single-path and the registered bytes are inspectable", async () => {
    if (!origin || !serviceKey) {
      throw new Error("local storage configuration missing");
    }
    const storage = new SupabasePrivateFileStorage(origin, serviceKey);
    const uploadId = crypto.randomUUID();
    const capability = await storage.createUploadCapability(
      uploadId,
      "image/png",
    );
    const png = new Uint8Array([
      0x89,
      0x50,
      0x4e,
      0x47,
      0x0d,
      0x0a,
      0x1a,
      0x0a,
    ]);
    try {
      const tampered = new URL(capability.uploadUrl);
      tampered.pathname = `${tampered.pathname}-substituted`;
      const denied = await fetch(tampered, {
        method: "PUT",
        headers: {
          "content-type": "image/png",
          "cache-control": "max-age=3600",
          "x-upsert": "false",
        },
        body: png,
      });
      expect(denied.ok).toBe(false);

      const uploaded = await fetch(capability.uploadUrl, {
        method: "PUT",
        headers: {
          "content-type": "image/png",
          "cache-control": "max-age=3600",
          "x-upsert": "false",
        },
        body: png,
      });
      expect(uploaded.ok).toBe(true);
      const observed = await storage.inspect(
        capability.bucket,
        capability.objectKey,
        png.byteLength,
      );
      expect(observed.exists).toBe(true);
      expect(observed.sizeBytes).toBe(png.byteLength);
      expect(observed.detectedMediaType).toBe("image/png");
    } finally {
      await storage.delete(capability.bucket, capability.objectKey);
    }
  });
});

import { imageWithinPixelCap } from "@studafy/domain";
import { prepareImage } from "@studafy/infrastructure";

/** About 1.5 MB: a phone screenshot or photo the app has already shrunk to
 * 1,600 px. Anything larger was not prepared by the app. */
export const INLINE_IMAGE_MAX_BYTES = 1_500_000;

export type InlineImageResult =
  | { ok: true; bytes: Uint8Array; mediaType: "image/jpeg" }
  | {
    ok: false;
    code: "UNSUPPORTED_MEDIA_TYPE" | "PAYLOAD_TOO_LARGE" | "PHOTO_UNREADABLE";
    status: 415 | 413 | 422;
  };

function startsWith(bytes: Uint8Array, prefix: number[]): boolean {
  return prefix.every((value, i) => bytes[i] === value);
}

/** The format the bytes really are, whatever the request said. */
function sniff(bytes: Uint8Array): string | null {
  if (startsWith(bytes, [0xff, 0xd8, 0xff])) return "image/jpeg";
  if (startsWith(bytes, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return "image/png";
  }
  if (
    String.fromCharCode(...bytes.subarray(0, 4)) === "RIFF" &&
    String.fromCharCode(...bytes.subarray(8, 12)) === "WEBP"
  ) {
    return "image/webp";
  }
  return null;
}

/**
 * A photo or screenshot sent inside a request (ADR-0045), for a student with
 * no school to upload into.
 *
 * It never reaches storage, so the upload pipeline's scan does not apply;
 * this does the part of it that matters for an image read once: the bytes
 * must really be a JPEG, PNG or WebP of the declared type, small enough, with
 * a size header within the pixel caps, and they are decoded and drawn again
 * as a new JPEG. Only that re-drawn copy is ever sent on, so nothing else
 * the file carried (metadata, a trailing payload) leaves the server.
 */
export async function readInlineImage(
  image: { mediaType: string; data: string },
): Promise<InlineImageResult> {
  let bytes: Uint8Array;
  try {
    bytes = Uint8Array.from(Buffer.from(image.data, "base64"));
  } catch {
    return { ok: false, code: "PHOTO_UNREADABLE", status: 422 };
  }
  if (bytes.length > INLINE_IMAGE_MAX_BYTES) {
    return { ok: false, code: "PAYLOAD_TOO_LARGE", status: 413 };
  }
  const actual = sniff(bytes);
  if (actual === null || actual !== image.mediaType) {
    return { ok: false, code: "UNSUPPORTED_MEDIA_TYPE", status: 415 };
  }
  if (!imageWithinPixelCap(bytes)) {
    return { ok: false, code: "PAYLOAD_TOO_LARGE", status: 413 };
  }
  try {
    return {
      ok: true,
      bytes: await prepareImage(bytes),
      mediaType: "image/jpeg",
    };
  } catch {
    return { ok: false, code: "PHOTO_UNREADABLE", status: 422 };
  }
}

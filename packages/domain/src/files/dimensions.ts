/**
 * Image dimensions from the header alone (security audit 2026-10-08).
 *
 * Every image is decoded to raw pixels somewhere: the study helper shrinks
 * photos in the API process, and the worker draws lesson images for the
 * model. A file's byte size says nothing about its pixel count - a 50,000 x
 * 50,000 PNG of one colour compresses to a few megabytes and decodes to ten
 * gigabytes - so the upload limit alone let one file exhaust a machine's
 * memory. The dimensions are read here, without decoding anything, and the
 * scan refuses an image over the cap before anyone can open it.
 */

/** The most pixels an image may have: a 48 MP phone photo fits. */
export const MAX_IMAGE_PIXELS = 50_000_000;
/** The longest side an image may have. */
export const MAX_IMAGE_SIDE = 20_000;

export interface ImageDimensions {
  width: number;
  height: number;
}

const u16be = (b: Uint8Array, i: number) => (b[i]! << 8) | b[i + 1]!;
const u32be = (b: Uint8Array, i: number) =>
  ((b[i]! << 24) | (b[i + 1]! << 16) | (b[i + 2]! << 8) | b[i + 3]!) >>> 0;
const u24le = (b: Uint8Array, i: number) =>
  b[i]! | (b[i + 1]! << 8) | (b[i + 2]! << 16);

function png(bytes: Uint8Array): ImageDimensions | null {
  // Signature (8), IHDR length (4) and type (4), then width and height.
  if (bytes.length < 24) return null;
  if (String.fromCharCode(...bytes.subarray(12, 16)) !== "IHDR") return null;
  return { width: u32be(bytes, 16), height: u32be(bytes, 20) };
}

const SOF = new Set([
  0xc0,
  0xc1,
  0xc2,
  0xc3,
  0xc5,
  0xc6,
  0xc7,
  0xc9,
  0xca,
  0xcb,
  0xcd,
  0xce,
  0xcf,
]);

function jpeg(bytes: Uint8Array): ImageDimensions | null {
  let i = 2;
  while (i + 4 <= bytes.length) {
    if (bytes[i] !== 0xff) return null;
    const marker = bytes[i + 1]!;
    // Fill bytes, and markers with no length.
    if (marker === 0xff) {
      i += 1;
      continue;
    }
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd8)) {
      i += 2;
      continue;
    }
    const length = u16be(bytes, i + 2);
    if (length < 2) return null;
    if (SOF.has(marker)) {
      if (i + 9 > bytes.length) return null;
      return { height: u16be(bytes, i + 5), width: u16be(bytes, i + 7) };
    }
    // Pixel data begins: no frame header was found before it.
    if (marker === 0xda) return null;
    i += 2 + length;
  }
  return null;
}

function webp(bytes: Uint8Array): ImageDimensions | null {
  if (bytes.length < 30) return null;
  const chunk = String.fromCharCode(...bytes.subarray(12, 16));
  if (chunk === "VP8X") {
    return { width: u24le(bytes, 24) + 1, height: u24le(bytes, 27) + 1 };
  }
  if (chunk === "VP8 ") {
    // Frame tag (3) then the start code 9d 01 2a, then 14-bit sizes.
    if (bytes[23] !== 0x9d || bytes[24] !== 0x01 || bytes[25] !== 0x2a) {
      return null;
    }
    return {
      width: (bytes[26]! | (bytes[27]! << 8)) & 0x3fff,
      height: (bytes[28]! | (bytes[29]! << 8)) & 0x3fff,
    };
  }
  if (chunk === "VP8L") {
    if (bytes[20] !== 0x2f) return null;
    const bits = bytes[21]! | (bytes[22]! << 8) | (bytes[23]! << 16) |
      (bytes[24]! << 24);
    return {
      width: (bits & 0x3fff) + 1,
      height: ((bits >>> 14) & 0x3fff) + 1,
    };
  }
  return null;
}

/** The dimensions a JPEG, PNG or WebP declares, or null if unreadable. */
export function imageDimensions(bytes: Uint8Array): ImageDimensions | null {
  if (bytes[0] === 0x89 && bytes[1] === 0x50) return png(bytes);
  if (bytes[0] === 0xff && bytes[1] === 0xd8) return jpeg(bytes);
  if (
    String.fromCharCode(...bytes.subarray(0, 4)) === "RIFF" &&
    String.fromCharCode(...bytes.subarray(8, 12)) === "WEBP"
  ) {
    return webp(bytes);
  }
  return null;
}

/** True when the image may be decoded: readable and within the caps. */
export function imageWithinPixelCap(bytes: Uint8Array): boolean {
  const size = imageDimensions(bytes);
  return size !== null && size.width > 0 && size.height > 0 &&
    size.width <= MAX_IMAGE_SIDE && size.height <= MAX_IMAGE_SIDE &&
    size.width * size.height <= MAX_IMAGE_PIXELS;
}

/**
 * True when the header declares more than the caps allow. The scan uses
 * this: an image whose size cannot be read is left to the format parsers,
 * and never decoded anyway, since decoding requires [imageWithinPixelCap].
 */
export function imageExceedsPixelCap(bytes: Uint8Array): boolean {
  const size = imageDimensions(bytes);
  return size !== null && (
    size.width > MAX_IMAGE_SIDE || size.height > MAX_IMAGE_SIDE ||
    size.width * size.height > MAX_IMAGE_PIXELS
  );
}

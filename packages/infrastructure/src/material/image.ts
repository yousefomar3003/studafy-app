/**
 * Images for the model (ADR-0037): a lesson photo or a drawn PDF page,
 * shrunk so its longest side is at most 1,600 pixels. A phone photo at full
 * size costs ten times the tokens and reads no better.
 */
import type { Canvas } from "@napi-rs/canvas";

const MAX_SIDE = 1_600;

export async function encodeJpeg(canvas: Canvas): Promise<Uint8Array> {
  return new Uint8Array(await canvas.encode("jpeg", 82));
}

/** A JPEG or PNG, decoded, shrunk if large, and re-encoded as JPEG. */
export async function prepareImage(bytes: Uint8Array): Promise<Uint8Array> {
  const { createCanvas, loadImage } = await import("@napi-rs/canvas");
  const image = await loadImage(Buffer.from(bytes));
  const scale = Math.min(1, MAX_SIDE / Math.max(image.width, image.height));
  const width = Math.max(1, Math.round(image.width * scale));
  const height = Math.max(1, Math.round(image.height * scale));
  const canvas = createCanvas(width, height);
  const context = canvas.getContext("2d");
  // A transparent PNG drawn on black reads as nothing.
  context.fillStyle = "#ffffff";
  context.fillRect(0, 0, width, height);
  context.drawImage(image, 0, 0, width, height);
  return await encodeJpeg(canvas);
}

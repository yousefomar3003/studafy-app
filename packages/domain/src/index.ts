/**
 * Pure domain policies. This package imports nothing external — no framework,
 * no SDK, no I/O (platform built-ins like node:zlib's pure in-memory inflate
 * are the one deliberate exception, used by the FILE-051 PDF guard). It is
 * the innermost ring of the dependency graph and the proof fixture for the
 * architecture boundary checker.
 */

/** A score is valid only when both numbers are finite and 0 <= score <= maximum. */
export function isScoreInRange(score: number, maximum: number): boolean {
  return (
    Number.isFinite(score) &&
    Number.isFinite(maximum) &&
    maximum > 0 &&
    score >= 0 &&
    score <= maximum
  );
}

export {
  asciiOf,
  containsBytes,
  containsEicarSignature,
  EICAR_SIGNATURE,
} from "./files/eicar";
export {
  jpegMetadataPayloads,
  type JpegParseResult,
  type JpegSegment,
  parseJpeg,
  stripJpegMetadata,
} from "./files/jpeg";
export {
  parsePng,
  pngAncillaryPayloads,
  type PngChunk,
  type PngParseResult,
  stripPngMetadata,
} from "./files/png";
export {
  parseWebp,
  stripWebpMetadata,
  type WebpChunk,
  webpMetadataPayloads,
  type WebpParseResult,
} from "./files/webp";
export {
  parsePdf,
  PDF_STREAM_INFLATE_CAP_BYTES,
  PDF_TOTAL_INFLATE_CAP_BYTES,
  type PdfParseResult,
  type PdfRejectReason,
} from "./files/pdf";
export {
  analyzeBytes,
  type AnalyzeResult,
  SCAN_POLICY_VERSION,
  type ScanErrorCode,
  type ScanVerdict,
  TRANSFORM_POLICY_VERSION,
  transformBytes,
  type TransformResult,
} from "./files/verdict";
export {
  createDeliveryNonce,
  DELIVERY_TOKEN_TTL_MAX_SECONDS,
  DELIVERY_TOKEN_TTL_MIN_SECONDS,
  type DeliveryTokenPayload,
  hashDeliveryNonce,
  signDeliveryToken,
  verifyDeliveryToken,
} from "./files/deliveryToken";
export { type DedupeEligibilityInput, isDedupeEligible } from "./files/dedup";
export {
  type AppleNotificationType,
  isAppleTransactionTrusted,
  mapAppleNotificationToTransactionState,
  mapAppleTransactionTypeToState,
  type StoreTransactionState,
} from "./billing/appleTransaction";
export {
  type GoogleSubscriptionState,
  isGooglePackageNameTrusted,
  mapGoogleSubscriptionStateToTransactionState,
} from "./billing/googlePurchase";
export {
  issueParentalGateChallenge,
  type ParentalGateChallenge,
  verifyParentalGateAnswer,
} from "./billing/parentalGate";

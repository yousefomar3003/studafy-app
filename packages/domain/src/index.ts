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
  jpegOrientation,
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
  MP4_AUDIO_BRANDS,
  type Mp4Box,
  mp4MetadataPayloads,
  type Mp4ParseResult,
  neutralizeMp4Metadata,
  parseMp4,
} from "./files/mp4";
export {
  detectOoxmlMediaType,
  DOCX_MEDIA_TYPE,
  OOXML_TOTAL_INFLATE_CAP_BYTES,
  type OoxmlKind,
  ooxmlKindOf,
  type OoxmlParseResult,
  type OoxmlRejectReason,
  parseOoxml,
  PPTX_MEDIA_TYPE,
  readZipDirectory,
  readZipEntry,
  type ZipDirectory,
  type ZipEntry,
} from "./files/ooxml";
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
  type ImageDimensions,
  imageDimensions,
  imageExceedsPixelCap,
  imageWithinPixelCap,
  MAX_IMAGE_PIXELS,
  MAX_IMAGE_SIDE,
} from "./files/dimensions";
export {
  APPLE_SUBSCRIPTION_STATUS,
  type AppleNotificationType,
  appleRenewalStatus,
  isAppleTransactionTrusted,
  mapAppleNotificationToTransactionState,
  mapAppleTransactionTypeToState,
  type RenewalStatus,
  resolveAppleSubscriptionState,
  type StoreTransactionState,
} from "./billing/appleTransaction";
export {
  googleRenewalStatus,
  type GoogleSubscriptionState,
  isGoogleAcknowledged,
  isGooglePackageNameTrusted,
  mapGoogleSubscriptionStateToTransactionState,
} from "./billing/googlePurchase";
export {
  type Flashcard,
  isUnreadableReply,
  lessonPrompt,
  parseFlashcards,
  parseJsonReply,
  parseQuiz,
  type QuizQuestion,
  redactForProvider,
  STUDY_LESSON_MAX_CHARS,
  STUDY_PROMPTS,
  type StudySetKind,
  type StudyUsage,
} from "./study/studyContent";
export {
  type KnownName,
  NAME_MIN_LETTERS,
  NAME_PLACEHOLDERS,
  type NameKind,
  NameRedactor,
  nameRedactor,
} from "./study/nameRedaction";
export {
  CHARS_PER_TOKEN,
  type ChatMemoryBudgets,
  chatMemoryTokens,
  CONTEXT_RESERVE_TOKENS,
  fitChatMemory,
} from "./study/chatMemory";
export {
  type Citation,
  GROUNDED_RULES,
  learnerLine,
  type LearnerProfile,
  materialBlock,
  type MaterialPassage,
  namedLocations,
  passageLabel,
  type PassageSource,
  resolveCitations,
  tokenBound,
  type UnreadableSource,
  wantsWholeMaterial,
} from "./study/grounding";
export {
  NOTEBOOK_PART_KEYS,
  NOTEBOOK_PROMPT,
  type NotebookCitation,
  type NotebookContent,
  type NotebookExample,
  type NotebookItem,
  type NotebookSection,
  type NotebookTerm,
  notebookText,
  parseNotebook,
  sectionKey,
} from "./study/notebook";

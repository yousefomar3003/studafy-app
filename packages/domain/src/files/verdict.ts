/**
 * FILE-051 scan verdict policy and safe transformation.
 *
 * The verdict is a pure function of the bytes and the detected media type.
 * "clean" is only ever returned for bytes that passed the full structural
 * walk of their format; the transformation stage then produces the bytes
 * that will actually be stored — a deterministic metadata-strip rewrite for
 * images, metadata boxes neutralised in place for voice notes, no change for
 * PDFs, Office files (OOXML and the older binary formats) and CSV (CDR is
 * deliberately deferred; see ADR-0023).
 */
import { imageExceedsPixelCap } from "./dimensions";
import { containsEicarSignature } from "./eicar";
import { jpegMetadataPayloads, parseJpeg, stripJpegMetadata } from "./jpeg";
import { parsePng, pngAncillaryPayloads, stripPngMetadata } from "./png";
import { parseWebp, stripWebpMetadata, webpMetadataPayloads } from "./webp";
import { parsePdf } from "./pdf";
import { mp4MetadataPayloads, neutralizeMp4Metadata, parseMp4 } from "./mp4";
import {
  DOCX_MEDIA_TYPE,
  type OoxmlKind,
  parseOoxml,
  PPTX_MEDIA_TYPE,
  XLSX_MEDIA_TYPE,
} from "./ooxml";
import { CSV_MEDIA_TYPE, parseCsvText } from "./csv";
import {
  type CfbKind,
  DOC_MEDIA_TYPE,
  parseCfb,
  PPT_MEDIA_TYPE,
  XLS_MEDIA_TYPE,
} from "./cfb";

export type ScanVerdict =
  | "clean"
  | "malicious"
  | "malformed"
  | "policy_rejected"
  | "infrastructure";

export type ScanErrorCode =
  | "malware_detected"
  | "malformed_file"
  | "polyglot_file"
  | "encrypted_document"
  | "embedded_file"
  | "active_content"
  | "decompression_limit"
  | "unsupported_animation"
  | "not_audio"
  | "external_reference"
  | "stored_object_mismatch";

export interface AnalyzeResult {
  verdict: ScanVerdict;
  errorCode?: ScanErrorCode;
  /** Which structural rule refused the file; for logs, never shown. */
  detail?: string;
}

export type SafeMediaType =
  | "application/pdf"
  | typeof DOCX_MEDIA_TYPE
  | typeof PPTX_MEDIA_TYPE
  | typeof XLSX_MEDIA_TYPE
  | typeof CSV_MEDIA_TYPE
  | typeof DOC_MEDIA_TYPE
  | typeof XLS_MEDIA_TYPE
  | typeof PPT_MEDIA_TYPE
  | "audio/mp4"
  | "image/jpeg"
  | "image/png"
  | "image/webp";

/** Version of this scan policy, recorded on every scanned object. */
export const SCAN_POLICY_VERSION = "file051-v1";
/** Version of the image metadata-strip transformation. */
// v2 (2026-10-07): keeps the restart interval and the orientation.
export const TRANSFORM_POLICY_VERSION = "file051-structural-strip-v2";

/**
 * An image whose declared pixels exceed the cap would exhaust memory when
 * decoded (files/dimensions.ts): refused like any other decompression bomb.
 */
const OVERSIZED_IMAGE: AnalyzeResult = {
  verdict: "policy_rejected",
  errorCode: "decompression_limit",
};

export async function analyzeBytes(
  bytes: Uint8Array,
  mediaType: string,
): Promise<AnalyzeResult> {
  // The EICAR test signature is rejected in any format, in any position.
  if (containsEicarSignature(bytes)) {
    return { verdict: "malicious", errorCode: "malware_detected" };
  }
  switch (mediaType) {
    case "image/jpeg": {
      const parsed = parseJpeg(bytes);
      if (!parsed.ok) return mapParseFailure(parsed.reason);
      if (imageExceedsPixelCap(bytes)) return OVERSIZED_IMAGE;
      for (const payload of jpegMetadataPayloads(bytes, parsed.segments)) {
        if (containsEicarSignature(payload)) {
          return { verdict: "malicious", errorCode: "malware_detected" };
        }
      }
      return { verdict: "clean" };
    }
    case "image/png": {
      const parsed = parsePng(bytes);
      if (!parsed.ok) return mapParseFailure(parsed.reason);
      if (imageExceedsPixelCap(bytes)) return OVERSIZED_IMAGE;
      for (const payload of pngAncillaryPayloads(bytes, parsed.chunks)) {
        if (containsEicarSignature(payload)) {
          return { verdict: "malicious", errorCode: "malware_detected" };
        }
      }
      return { verdict: "clean" };
    }
    case "image/webp": {
      const parsed = parseWebp(bytes);
      if (!parsed.ok) {
        if (parsed.reason === "unsupported") {
          return {
            verdict: "policy_rejected",
            errorCode: "unsupported_animation",
          };
        }
        return mapParseFailure(parsed.reason);
      }
      if (imageExceedsPixelCap(bytes)) return OVERSIZED_IMAGE;
      for (const payload of webpMetadataPayloads(bytes, parsed.chunks)) {
        if (containsEicarSignature(payload)) {
          return { verdict: "malicious", errorCode: "malware_detected" };
        }
      }
      return { verdict: "clean" };
    }
    case "application/pdf": {
      const parsed = await parsePdf(bytes);
      if (!parsed.ok) {
        const refused = mapPdfFailure(parsed.reason);
        return parsed.detail ? { ...refused, detail: parsed.detail } : refused;
      }
      return { verdict: "clean" };
    }
    // Word, PowerPoint (ADR-0037) and Excel (DL-077): a bounded ZIP walk
    // that refuses macros, embedded objects, remote templates and a
    // workbook's external links. Stored unchanged.
    case DOCX_MEDIA_TYPE:
    case PPTX_MEDIA_TYPE:
    case XLSX_MEDIA_TYPE: {
      const kind: OoxmlKind = mediaType === DOCX_MEDIA_TYPE
        ? "docx"
        : mediaType === PPTX_MEDIA_TYPE
        ? "pptx"
        : "xlsx";
      const parsed = parseOoxml(bytes, kind);
      if (!parsed.ok) {
        return parsed.reason === "external_reference"
          ? { verdict: "policy_rejected", errorCode: "external_reference" }
          : mapPdfFailure(parsed.reason);
      }
      return { verdict: "clean" };
    }
    // Word .doc, Excel .xls and PowerPoint .ppt (DL-078): a bounded walk
    // of the compound file that refuses macros, embedded objects, links to
    // other files and passwords, mirroring the OOXML rules. Stored
    // unchanged; never opened here.
    case DOC_MEDIA_TYPE:
    case XLS_MEDIA_TYPE:
    case PPT_MEDIA_TYPE: {
      const kind: CfbKind = mediaType === DOC_MEDIA_TYPE
        ? "doc"
        : mediaType === XLS_MEDIA_TYPE
        ? "xls"
        : "ppt";
      const parsed = parseCfb(bytes, kind);
      if (!parsed.ok) {
        return parsed.reason === "external_reference"
          ? { verdict: "policy_rejected", errorCode: "external_reference" }
          : mapPdfFailure(parsed.reason);
      }
      return { verdict: "clean" };
    }
    // CSV (DL-077): UTF-8 text only, never executed. Stored unchanged.
    case CSV_MEDIA_TYPE: {
      const parsed = parseCsvText(bytes);
      if (!parsed.ok) return mapParseFailure(parsed.reason);
      return { verdict: "clean" };
    }
    case "audio/mp4": {
      const parsed = parseMp4(bytes);
      if (!parsed.ok) {
        switch (parsed.reason) {
          case "not_audio":
            return { verdict: "policy_rejected", errorCode: "not_audio" };
          case "external":
            return {
              verdict: "policy_rejected",
              errorCode: "external_reference",
            };
          default:
            return mapParseFailure(parsed.reason);
        }
      }
      for (const payload of mp4MetadataPayloads(bytes, parsed.metadata)) {
        if (containsEicarSignature(payload)) {
          return { verdict: "malicious", errorCode: "malware_detected" };
        }
      }
      return { verdict: "clean" };
    }
    default:
      // FILE-050 only admits the signature-detected types; anything
      // else here means the caller lied about the detected type.
      return { verdict: "malformed", errorCode: "malformed_file" };
  }
}

export interface TransformResult {
  /** New bytes to store, or null when the format is stored unchanged. */
  bytes: Uint8Array | null;
  transformPolicyVersion: string | null;
}

/**
 * The safe transformation. Images are rewritten without metadata segments;
 * PDFs are stored as validated, unchanged bytes. The rewrite is
 * deterministic: identical input always yields identical output, which is
 * what makes same-hash dedupe sound.
 */
export function transformBytes(
  bytes: Uint8Array,
  mediaType: string,
): TransformResult {
  switch (mediaType) {
    case "image/jpeg": {
      const parsed = parseJpeg(bytes);
      if (!parsed.ok) return { bytes: null, transformPolicyVersion: null };
      return {
        bytes: stripJpegMetadata(bytes, parsed.segments),
        transformPolicyVersion: TRANSFORM_POLICY_VERSION,
      };
    }
    case "image/png": {
      const parsed = parsePng(bytes);
      if (!parsed.ok) return { bytes: null, transformPolicyVersion: null };
      return {
        bytes: stripPngMetadata(bytes, parsed.chunks),
        transformPolicyVersion: TRANSFORM_POLICY_VERSION,
      };
    }
    case "image/webp": {
      const parsed = parseWebp(bytes);
      if (!parsed.ok) return { bytes: null, transformPolicyVersion: null };
      return {
        bytes: stripWebpMetadata(bytes, parsed.chunks),
        transformPolicyVersion: TRANSFORM_POLICY_VERSION,
      };
    }
    case "audio/mp4": {
      const parsed = parseMp4(bytes);
      if (!parsed.ok) return { bytes: null, transformPolicyVersion: null };
      return {
        bytes: neutralizeMp4Metadata(bytes, parsed.metadata),
        transformPolicyVersion: TRANSFORM_POLICY_VERSION,
      };
    }
    default:
      return { bytes: null, transformPolicyVersion: null };
  }
}

function mapParseFailure(
  reason: "malformed" | "polyglot",
): AnalyzeResult {
  return reason === "polyglot"
    ? { verdict: "malformed", errorCode: "polyglot_file" }
    : { verdict: "malformed", errorCode: "malformed_file" };
}

function mapPdfFailure(reason: string): AnalyzeResult {
  switch (reason) {
    case "encrypted":
      return { verdict: "policy_rejected", errorCode: "encrypted_document" };
    case "embedded":
      return { verdict: "policy_rejected", errorCode: "embedded_file" };
    case "active_content":
      return { verdict: "policy_rejected", errorCode: "active_content" };
    case "malicious":
      return { verdict: "malicious", errorCode: "malware_detected" };
    case "decompression_limit":
      return { verdict: "policy_rejected", errorCode: "decompression_limit" };
    case "polyglot":
      return { verdict: "malformed", errorCode: "polyglot_file" };
    default:
      return { verdict: "malformed", errorCode: "malformed_file" };
  }
}

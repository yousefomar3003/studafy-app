/**
 * Reading one lesson file or link into passages (ADR-0037).
 *
 * Returns 'ready' with passages, or 'unsupported' with the reason a
 * teacher is shown. Throws only for a passing failure - the model or the
 * network was unavailable - which the worker retries.
 */
import { DOCX_MEDIA_TYPE, PPTX_MEDIA_TYPE } from "@studafy/domain";
import {
  chunkSections,
  type MaterialChunk,
  type MaterialSection,
} from "./chunks";
import { htmlToSections } from "./html";
import { prepareImage } from "./image";
import { fetchPublicLink, type LinkFetch } from "./link";
import { extractDocx, extractPptx, UnreadableDocumentError } from "./office";
import { extractPdf, type PageReader, type ProcessingUsage } from "./pdf";

export interface MaterialLimits {
  ocrPagesPerFile: number;
  textPagesPerFile: number;
  charsPerDocument: number;
  linkMaxBytes: number;
}

export type MaterialSource =
  | { kind: "file"; mediaType: string; bytes: Uint8Array }
  | { kind: "link"; url: string };

export interface UsageRecord extends ProcessingUsage {
  kind: "ocr" | "image" | "link";
  pages: number;
}

export interface MaterialResult {
  outcome: "ready" | "unsupported";
  reason: string | null;
  chunks: MaterialChunk[];
  detail: Record<string, number | boolean | string>;
  extractor: string;
  usage: UsageRecord[];
}

export interface MaterialReadDeps {
  limits: MaterialLimits;
  /** How many pages the model may read for this file, asked once. */
  ocrAllowance: (pages: number) => Promise<number>;
  /** The model reading a scanned page, or null when it is not available. */
  readPage: PageReader | null;
  /** The model reading a picture or diagram, or null. */
  readImage: PageReader | null;
  fetchLink?: (url: string) => Promise<LinkFetch>;
}

function finish(
  sections: MaterialSection[],
  extractor: string,
  limits: MaterialLimits,
  detail: MaterialResult["detail"],
  usage: UsageRecord[],
  emptyReason: string,
  partly: string | null = null,
): MaterialResult {
  const { chunks, chars, truncated } = chunkSections(
    sections,
    limits.charsPerDocument,
  );
  if (chunks.length === 0) {
    return {
      outcome: "unsupported",
      reason: emptyReason,
      chunks,
      detail,
      extractor,
      usage,
    };
  }
  return {
    outcome: "ready",
    reason: truncated ? "partly_read" : partly,
    chunks,
    detail: { ...detail, chars, truncated },
    extractor,
    usage,
  };
}

async function readPdf(
  bytes: Uint8Array,
  deps: MaterialReadDeps,
  extractor: string,
  usageKind: "ocr" | "link",
): Promise<MaterialResult> {
  let pdf;
  try {
    pdf = await extractPdf(bytes, {
      maxPages: deps.limits.textPagesPerFile,
      ocrAllowance: deps.ocrAllowance,
      ...(deps.readPage ? { readPage: deps.readPage } : {}),
    });
  } catch (error) {
    if ((error as { kind?: string }).kind === "unavailable") throw error;
    return {
      outcome: "unsupported",
      reason: "unreadable_file",
      chunks: [],
      detail: {},
      extractor,
      usage: [],
    };
  }
  const usage: UsageRecord[] = pdf.usage.map((u, i) => ({
    ...u,
    kind: usageKind,
    pages: i === 0 ? pdf.ocrPages : 0,
  }));
  if (usage.length === 0 && pdf.ocrPages > 0) {
    usage.push({
      kind: usageKind,
      pages: pdf.ocrPages,
      inputTokens: 0,
      outputTokens: 0,
      model: "unknown",
    });
  }
  const skipped = pdf.skippedPages + pdf.unreadPages;
  const emptyReason = pdf.skippedPages > 0
    ? (deps.readPage ? "reading_budget_used" : "needs_model")
    : "no_text";
  return finish(
    pdf.sections,
    extractor,
    deps.limits,
    {
      pages: pdf.pages,
      textPages: pdf.textPages,
      ocrPages: pdf.ocrPages,
      skippedPages: skipped,
    },
    usage,
    emptyReason,
    skipped > 0 ? "partly_read" : null,
  );
}

export async function readMaterial(
  source: MaterialSource,
  deps: MaterialReadDeps,
): Promise<MaterialResult> {
  if (source.kind === "link") return await readLink(source.url, deps);
  const { mediaType, bytes } = source;
  switch (mediaType) {
    case "application/pdf":
      return await readPdf(bytes, deps, "pdf-v1", "ocr");
    case DOCX_MEDIA_TYPE:
    case PPTX_MEDIA_TYPE: {
      try {
        if (mediaType === DOCX_MEDIA_TYPE) {
          const docx = extractDocx(bytes);
          return finish(
            docx.sections,
            "docx-v1",
            deps.limits,
            {
              ...(docx.pages ? { pages: docx.pages } : {}),
            },
            [],
            "no_text",
          );
        }
        const deck = extractPptx(bytes);
        return finish(
          deck.sections,
          "pptx-v1",
          deps.limits,
          { slides: deck.slides },
          [],
          "no_text",
        );
      } catch (error) {
        if (!(error instanceof UnreadableDocumentError)) throw error;
        return {
          outcome: "unsupported",
          reason: "unreadable_file",
          chunks: [],
          detail: {},
          extractor: "office-v1",
          usage: [],
        };
      }
    }
    case "image/jpeg":
    case "image/png": {
      const extractor = "image-v1";
      if (!deps.readImage) {
        return {
          outcome: "unsupported",
          reason: "needs_model",
          chunks: [],
          detail: {},
          extractor,
          usage: [],
        };
      }
      if (await deps.ocrAllowance(1) < 1) {
        return {
          outcome: "unsupported",
          reason: "reading_budget_used",
          chunks: [],
          detail: {},
          extractor,
          usage: [],
        };
      }
      let jpeg: Uint8Array;
      try {
        jpeg = await prepareImage(bytes);
      } catch {
        return {
          outcome: "unsupported",
          reason: "unreadable_file",
          chunks: [],
          detail: {},
          extractor,
          usage: [],
        };
      }
      let read;
      try {
        read = await deps.readImage(jpeg);
      } catch (error) {
        if ((error as { kind?: string }).kind !== "unreadable") throw error;
        return {
          outcome: "unsupported",
          reason: "no_text",
          chunks: [],
          detail: { ocrPages: 1 },
          extractor,
          usage: [{
            kind: "image",
            pages: 1,
            inputTokens: 0,
            outputTokens: 0,
            model: "unknown",
          }],
        };
      }
      const usage: UsageRecord[] = [{
        kind: "image",
        pages: 1,
        inputTokens: read.usage?.inputTokens ?? 0,
        outputTokens: read.usage?.outputTokens ?? 0,
        model: read.usage?.model ?? "unknown",
      }];
      return finish(
        [{ text: read.text }],
        extractor,
        deps.limits,
        { ocrPages: 1 },
        usage,
        "no_text",
      );
    }
    default:
      return {
        outcome: "unsupported",
        reason: "unsupported_type",
        chunks: [],
        detail: {},
        extractor: "none",
        usage: [],
      };
  }
}

async function readLink(
  url: string,
  deps: MaterialReadDeps,
): Promise<MaterialResult> {
  const fetched = await (deps.fetchLink ??
    ((target: string) =>
      fetchPublicLink(target, { maxBytes: deps.limits.linkMaxBytes })))(url);
  const extractor = "link-v1";
  if (!fetched.ok) {
    return {
      outcome: "unsupported",
      reason: fetched.reason,
      chunks: [],
      detail: {},
      extractor,
      usage: [],
    };
  }
  if (/^application\/pdf/i.test(fetched.contentType)) {
    if (fetched.truncated) {
      return {
        outcome: "unsupported",
        reason: "link_too_large",
        chunks: [],
        detail: {},
        extractor,
        usage: [],
      };
    }
    const pdf = await readPdf(fetched.bytes, deps, extractor, "link");
    return pdf;
  }
  const charset = fetched.contentType.match(/charset=([\w-]+)/i)?.[1] ??
    "utf-8";
  let text: string;
  try {
    text = new TextDecoder(charset as "utf-8").decode(fetched.bytes);
  } catch {
    text = new TextDecoder("utf-8").decode(fetched.bytes);
  }
  if (/^text\/plain/i.test(fetched.contentType)) {
    return finish(
      [{ text }],
      extractor,
      deps.limits,
      { truncated: fetched.truncated },
      [],
      "no_text",
    );
  }
  const page = htmlToSections(text);
  return finish(
    page.sections,
    extractor,
    deps.limits,
    { truncated: fetched.truncated },
    [],
    "no_text",
    fetched.truncated ? "partly_read" : null,
  );
}

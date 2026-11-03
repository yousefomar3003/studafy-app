/**
 * The document converter client (DL-078): LibreOffice, headless, in its own
 * Fly app on the private network only (infra/converter). It turns a clean
 * Office file or CSV into a PDF preview, and an old binary .doc/.xls/.ppt
 * into .docx/.xlsx/.pptx for the material reader.
 *
 * Deliberately narrow, like the malware scanner client: one configured
 * origin (never a caller-supplied URL), one POST shape, no redirects, a
 * bounded wait. The converter's own refusal of a file (HTTP 422 with a short
 * code) is an answer; anything else - network error, timeout, 5xx, an
 * oversized or empty body - is "unavailable", and the job is retried.
 */

export type ConvertFrom =
  | "doc"
  | "docx"
  | "xls"
  | "xlsx"
  | "csv"
  | "ppt"
  | "pptx";
export type ConvertTo = "pdf" | "docx" | "xlsx" | "pptx";

export type ConversionResult =
  | { ok: true; bytes: Uint8Array }
  | { ok: false; code: string };

export interface DocumentConverter {
  convert(
    bytes: Uint8Array,
    from: ConvertFrom,
    to: ConvertTo,
  ): Promise<ConversionResult>;
}

export interface DocumentConverterConfig {
  /** The converter's origin, e.g. http://studafy-converter-test.internal:8080 */
  url: string;
  apiKey: string;
  /** Total budget for one conversion, queueing included. */
  timeoutMs?: number;
  /** Largest converted file accepted. */
  maxOutputBytes?: number;
  fetch?: typeof fetch;
}

export class ConverterUnavailableError extends Error {
  constructor(readonly status: number | null = null) {
    super("document converter unavailable");
    this.name = "ConverterUnavailableError";
  }
}

const CODE = /^[a-z_]{1,60}$/;

export class HttpDocumentConverter implements DocumentConverter {
  readonly #config: DocumentConverterConfig;
  readonly #endpoint: URL;

  constructor(config: DocumentConverterConfig) {
    this.#config = config;
    this.#endpoint = new URL("/convert", config.url);
  }

  async convert(
    bytes: Uint8Array,
    from: ConvertFrom,
    to: ConvertTo,
  ): Promise<ConversionResult> {
    const url = new URL(this.#endpoint);
    url.searchParams.set("from", from);
    url.searchParams.set("to", to);
    const controller = new AbortController();
    const timeout = setTimeout(
      () => controller.abort(),
      this.#config.timeoutMs ?? 150_000,
    );
    const maxOutput = this.#config.maxOutputBytes ?? 25 * 1024 * 1024;
    try {
      const response = await (this.#config.fetch ?? fetch)(url, {
        method: "POST",
        headers: {
          "content-type": "application/octet-stream",
          authorization: `Bearer ${this.#config.apiKey}`,
        },
        body: bytes,
        signal: controller.signal,
        redirect: "error",
      });
      if (response.status === 422) {
        const body = await response.json().catch(() => null) as
          | { error?: unknown }
          | null;
        const code = typeof body?.error === "string" && CODE.test(body.error)
          ? body.error
          : "conversion_failed";
        return { ok: false, code };
      }
      if (!response.ok) throw new ConverterUnavailableError(response.status);
      const declared = Number(response.headers.get("content-length"));
      if (Number.isFinite(declared) && declared > maxOutput) {
        return { ok: false, code: "output_too_large" };
      }
      const out = new Uint8Array(await response.arrayBuffer());
      if (out.byteLength > maxOutput) {
        return { ok: false, code: "output_too_large" };
      }
      if (out.byteLength === 0) throw new ConverterUnavailableError();
      return { ok: true, bytes: out };
    } catch (error) {
      if (error instanceof ConverterUnavailableError) throw error;
      throw new ConverterUnavailableError();
    } finally {
      clearTimeout(timeout);
    }
  }
}

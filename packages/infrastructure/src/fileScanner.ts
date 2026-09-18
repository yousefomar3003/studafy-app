/**
 * FILE-051 file-security scanning.
 *
 * The scanner is the composition point of the Part 5B pipeline: it runs the
 * deterministic structural analysis, applies the safe transformation, and —
 * when an external malware provider is configured — merges the provider's
 * verdict. Two properties are load-bearing:
 *
 *  - **No fail-open.** An unavailable or erroring external provider turns
 *    the verdict into `infrastructure`, which the outbox retries and never
 *    converts to `clean`.
 *  - **Clean means stored bytes are known.** A clean verdict carries the
 *    stored sha256/size of the *transformed* bytes so the worker can verify
 *    the storage read-back before the database records `clean`.
 *
 * The local deterministic scanner has no egress and no credentials. It is
 * the local/disposable implementation; production requires the external
 * provider (worker configuration fails closed), because structural
 * validation is not signature-grade malware detection.
 */
import {
  analyzeBytes,
  SCAN_POLICY_VERSION,
  type ScanErrorCode,
  type ScanVerdict,
  transformBytes,
} from "@studafy/domain";
import { sha256Hex } from "./privateFileStorage";

export interface FileScanInput {
  bytes: Uint8Array;
  mediaType: string;
  purpose: string;
}

export interface FileScanResult {
  verdict: ScanVerdict;
  errorCode?: ScanErrorCode;
  scanPolicyVersion: string;
  durationMs: number;
  transformPolicyVersion: string | null;
  storedSha256: string | null;
  storedSizeBytes: number | null;
  /** Bytes to persist when the verdict is clean and a transform applied. */
  storedBytes: Uint8Array | null;
}

export interface FileScanner {
  scan(input: FileScanInput): Promise<FileScanResult>;
}

/** The deterministic local scanner: structure, transform, no egress. */
export class LocalDeterministicScanner implements FileScanner {
  async scan(input: FileScanInput): Promise<FileScanResult> {
    const startedAt = Date.now();
    const analysis = await analyzeBytes(input.bytes, input.mediaType);
    const durationMs = Date.now() - startedAt;
    if (analysis.verdict !== "clean") {
      return {
        verdict: analysis.verdict,
        errorCode: analysis.errorCode,
        scanPolicyVersion: SCAN_POLICY_VERSION,
        durationMs,
        transformPolicyVersion: null,
        storedSha256: null,
        storedSizeBytes: null,
        storedBytes: null,
      };
    }
    const transform = transformBytes(input.bytes, input.mediaType);
    const stored = transform.bytes ?? input.bytes;
    return {
      verdict: "clean",
      scanPolicyVersion: SCAN_POLICY_VERSION,
      durationMs,
      transformPolicyVersion: transform.transformPolicyVersion,
      storedSha256: await sha256Hex(stored),
      storedSizeBytes: stored.byteLength,
      storedBytes: transform.bytes,
    };
  }
}

export interface ExternalScannerConfig {
  /** The one origin the scanner client will ever contact. */
  url: string;
  apiKey: string;
  /** Total request budget for one scan call. */
  timeoutMs?: number;
}

export class ExternalScannerUnavailableError extends Error {
  constructor() {
    super("malware scanner unavailable");
    this.name = "ExternalScannerUnavailableError";
  }
}

/**
 * External malware provider client. Deliberately narrow: exactly one
 * configured origin (never a caller-supplied URL), one POST shape, one JSON
 * response shape, and every non-authoritative answer — network error,
 * timeout, non-2xx, malformed body — becomes an infrastructure failure so
 * the pipeline retries rather than guessing. The provider API contract is
 * provisional until a real scanner service is selected (inputs.md Group 3);
 * wiring the real one is a reviewed change to this adapter only.
 */
export class ExternalMalwareScannerClient {
  readonly #config: ExternalScannerConfig;

  constructor(config: ExternalScannerConfig) {
    this.#config = config;
  }

  /** Returns true when the provider verdict is clean; false when malicious. */
  async verdictIsClean(bytes: Uint8Array): Promise<boolean> {
    const controller = new AbortController();
    const timeout = setTimeout(
      () => controller.abort(),
      this.#config.timeoutMs ?? 30_000,
    );
    try {
      const response = await fetch(this.#config.url, {
        method: "POST",
        headers: {
          "content-type": "application/octet-stream",
          authorization: `Bearer ${this.#config.apiKey}`,
        },
        body: bytes,
        signal: controller.signal,
        redirect: "error",
      });
      if (!response.ok) throw new ExternalScannerUnavailableError();
      const body = (await response.json()) as { clean?: unknown };
      if (typeof body.clean !== "boolean") {
        throw new ExternalScannerUnavailableError();
      }
      return body.clean;
    } catch {
      throw new ExternalScannerUnavailableError();
    } finally {
      clearTimeout(timeout);
    }
  }
}

/**
 * The composed scanner: deterministic analysis first, external verdict
 * second. An external `malicious` is terminal; an external failure on a
 * structurally clean file is `infrastructure` — the file stays quarantined
 * and the job retries. Nothing here can produce `clean` without both the
 * structural walk and (when configured) the provider agreeing.
 */
export class FileSecurityScanner implements FileScanner {
  readonly #external: ExternalMalwareScannerClient | null;

  constructor(external: ExternalMalwareScannerClient | null = null) {
    this.#external = external;
  }

  async scan(input: FileScanInput): Promise<FileScanResult> {
    const local = await new LocalDeterministicScanner().scan(input);
    if (local.verdict !== "clean") return local;
    if (this.#external === null) return local;
    let providerClean: boolean;
    try {
      providerClean = await this.#external.verdictIsClean(input.bytes);
    } catch {
      return {
        verdict: "infrastructure",
        errorCode: undefined,
        scanPolicyVersion: SCAN_POLICY_VERSION,
        durationMs: local.durationMs,
        transformPolicyVersion: null,
        storedSha256: null,
        storedSizeBytes: null,
        storedBytes: null,
      };
    }
    if (!providerClean) {
      return {
        verdict: "malicious",
        errorCode: "malware_detected",
        scanPolicyVersion: SCAN_POLICY_VERSION,
        durationMs: local.durationMs,
        transformPolicyVersion: null,
        storedSha256: null,
        storedSizeBytes: null,
        storedBytes: null,
      };
    }
    return local;
  }
}

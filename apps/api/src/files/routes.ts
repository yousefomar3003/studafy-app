import { type Context, Hono } from "hono";
import {
  type ErrorCodeType,
  V1CreateUploadIntentRequest,
  V1PublishFileRequest,
  v1Route,
} from "@studafy/contracts";
import {
  createDeliveryNonce,
  hashDeliveryNonce,
  signDeliveryToken,
  verifyDeliveryToken,
} from "@studafy/domain";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import { requirePermission } from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { idempotency } from "../platform/idempotency";
import { problem } from "../platform/errors";
import {
  validatedBody,
  validatedParams,
  validateRouteInput,
} from "../platform/validation";
import type { RequestDbContext } from "../platform/catalogueRoutes";
import type { File050Result, FileRepository } from "./repository";
import {
  normalizeDisplayName,
  type PrivateFileStorage,
  sha256Hex,
  StorageUnavailableError,
} from "./storage";

export interface FileRoutesDependencies {
  repository: FileRepository;
  storage: PrivateFileStorage;
  newIntentsEnabled: boolean;
  /** FILE-051 publication switch; off unless explicitly enabled. */
  publishEnabled?: boolean;
  /** FILE-051 delivery; `null`/absent keeps delivery disabled. */
  delivery?: DeliveryConfig | null;
}

export interface DeliveryConfig {
  signingKey: string;
  /** Absolute origin the delivery links are built on. */
  publicBaseUrl: string;
  ttlSeconds?: number;
  now?: () => number;
}

/** Five minutes: long enough to start a download, short enough to leak little. */
export const DELIVERY_TTL_SECONDS = 5 * 60;
const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SHA256 = /^[0-9a-f]{64}$/;

export function createFileRoutes(
  deps: FileRoutesDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const create = v1Route("createUploadIntent");
  const uploadStatus = v1Route("getUploadStatus");
  const complete = v1Route("completeUpload");
  const fileStatus = v1Route("getFileStatus");
  const download = v1Route("createFileDownloadIntent");
  const publish = v1Route("publishFile");

  routes.post(
    "/v1/uploads",
    validateRouteInput(create) as never,
    requirePermission(
      authorization,
      "upload.intent.create",
      (c) =>
        (validatedBody<Record<string, string>>(c as never)).schoolId ?? null,
    ),
    idempotency(idempotencyDependencies, create.operationId, "required"),
    async (c) => {
      if (!deps.newIntentsEnabled) {
        return problem(c, "SERVICE_UNAVAILABLE", 503);
      }
      const reservation = c.get("idempotencyReservation");
      if (!reservation) return problem(c, "FORBIDDEN", 403);
      const parsed = V1CreateUploadIntentRequest.parse(
        validatedBody(c as never),
      );
      const body = {
        ...parsed,
        displayName: normalizeDisplayName(parsed.displayName),
      };
      const context = requestContext(c);
      const prepared = await deps.repository.prepareIntent(context, body);
      const rejected = mapOutcome(c, prepared);
      if (rejected) return rejected;

      const uploadId = crypto.randomUUID();
      let capability;
      try {
        capability = await deps.storage.createUploadCapability(
          uploadId,
          body.declaredMediaType,
        );
      } catch (error) {
        if (!(error instanceof StorageUnavailableError)) throw error;
        return problem(c, "STORAGE_UNAVAILABLE", 503);
      }
      const result = await deps.repository.issueIntent(
        context,
        body,
        { uploadId, ...capability },
        reservation,
      );
      const failure = mapOutcome(c, result);
      if (failure) return failure;
      const response = create.response.safeParse(result.response);
      if (!response.success) return problem(c, "INTERNAL_ERROR", 500);
      c.set("idempotencyCompleted", true);
      return c.json(response.data, 201);
    },
  );

  routes.get(
    "/v1/uploads/:uploadId",
    validateRouteInput(uploadStatus) as never,
    requirePermission(
      authorization,
      "upload.read",
      (c) =>
        validatedParams<Record<string, string>>(c as never).uploadId ?? null,
    ),
    async (c) => {
      const id = requiredParam(c, "uploadId");
      const result = await deps.repository.query(
        requestContext(c),
        uploadStatus.operationId,
        id,
      );
      const failure = mapOutcome(c, result);
      if (failure) return failure;
      const response = uploadStatus.response.safeParse(result.response);
      return response.success
        ? c.json(response.data)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  routes.post(
    "/v1/uploads/:uploadId/complete",
    validateRouteInput(complete) as never,
    requirePermission(
      authorization,
      "upload.complete",
      (c) =>
        validatedParams<Record<string, string>>(c as never).uploadId ?? null,
    ),
    idempotency(idempotencyDependencies, complete.operationId, "required"),
    async (c) => {
      const reservation = c.get("idempotencyReservation");
      if (!reservation) return problem(c, "FORBIDDEN", 403);
      const uploadId = requiredParam(c, "uploadId");
      const context = requestContext(c);
      const prepared = await deps.repository.prepareCompletion(
        context,
        uploadId,
      );
      const rejected = mapOutcome(c, prepared);
      if (rejected) return rejected;
      let observed;
      try {
        observed = await deps.storage.inspect(
          String(prepared.bucket),
          String(prepared.objectKey),
          Number(prepared.expectedSizeBytes),
        );
      } catch (error) {
        if (!(error instanceof StorageUnavailableError)) throw error;
        return problem(c, "STORAGE_UNAVAILABLE", 503);
      }
      const result = await deps.repository.complete(
        context,
        uploadId,
        observed,
        reservation,
      );
      if (result.outcome === "problem") {
        c.set("idempotencyCompleted", true);
        return c.json(result.response as never, 422, {
          "Content-Type": "application/problem+json; charset=UTF-8",
        });
      }
      const failure = mapOutcome(c, result);
      if (failure) return failure;
      const response = complete.response.safeParse(result.response);
      if (!response.success) return problem(c, "INTERNAL_ERROR", 500);
      c.set("idempotencyCompleted", true);
      return c.json(response.data);
    },
  );

  routes.get(
    "/v1/files/:fileId",
    validateRouteInput(fileStatus) as never,
    requirePermission(
      authorization,
      "file.read",
      (c) => validatedParams<Record<string, string>>(c as never).fileId ?? null,
    ),
    async (c) => {
      const id = requiredParam(c, "fileId");
      const result = await deps.repository.query(
        requestContext(c),
        fileStatus.operationId,
        id,
      );
      const failure = mapOutcome(c, result);
      if (failure) return failure;
      const response = fileStatus.response.safeParse(result.response);
      return response.success
        ? c.json(response.data)
        : problem(c, "INTERNAL_ERROR", 500);
    },
  );

  routes.post(
    "/v1/files/:fileId/download-intent",
    validateRouteInput(download) as never,
    requirePermission(
      authorization,
      "file.download",
      (c) => validatedParams<Record<string, string>>(c as never).fileId ?? null,
    ),
    idempotency(idempotencyDependencies, download.operationId, "required"),
    async (c) => {
      const id = requiredParam(c, "fileId");
      const delivery = deps.delivery;
      if (!delivery) {
        const result = await deps.repository.query(
          requestContext(c),
          download.operationId,
          id,
        );
        return mapOutcome(c, result) ??
          problem(c, "FILE_DELIVERY_DISABLED", 409);
      }
      const reservation = c.get("idempotencyReservation");
      if (!reservation) return problem(c, "FORBIDDEN", 403);

      // The link is minted before the transaction and disclosed only after
      // the grant (nonce hash, recipient, expiry) has committed with the
      // idempotency completion. The database never sees the nonce itself.
      const ttlSeconds = delivery.ttlSeconds ?? DELIVERY_TTL_SECONDS;
      const nowSeconds = Math.floor((delivery.now ?? Date.now)() / 1000);
      const nonce = createDeliveryNonce();
      const token = await signDeliveryToken(
        {
          fileId: id,
          userId: c.get("actor").token.subject,
          nonce,
          ttlSeconds,
          nowSeconds,
        },
        delivery.signingKey,
      );
      const result = await deps.repository.createDownloadGrant(
        requestContext(c),
        id,
        {
          nonceHash: await hashDeliveryNonce(nonce),
          downloadUrl: deliveryUrl(delivery.publicBaseUrl, id, token),
          expiresAt: new Date((nowSeconds + ttlSeconds) * 1000).toISOString(),
        },
        reservation,
      );
      const failure = mapOutcome(c, result);
      if (failure) return failure;
      const response = download.response.safeParse(result.response);
      if (!response.success) return problem(c, "INTERNAL_ERROR", 500);
      c.set("idempotencyCompleted", true);
      return c.json(response.data);
    },
  );

  routes.post(
    "/v1/files/:fileId/publish",
    validateRouteInput(publish) as never,
    requirePermission(
      authorization,
      "file.publish",
      (c) => validatedParams<Record<string, string>>(c as never).fileId ?? null,
    ),
    idempotency(idempotencyDependencies, publish.operationId, "required"),
    async (c) => {
      if (!deps.publishEnabled) {
        return problem(c, "FILE_PUBLISH_DISABLED", 503);
      }
      const reservation = c.get("idempotencyReservation");
      if (!reservation) return problem(c, "FORBIDDEN", 403);
      const body = V1PublishFileRequest.parse(validatedBody(c as never));
      const result = await deps.repository.publish(
        requestContext(c),
        requiredParam(c, "fileId"),
        body,
        reservation,
      );
      const failure = mapOutcome(c, result);
      if (failure) return failure;
      const response = publish.response.safeParse(result.response);
      if (!response.success) return problem(c, "INTERNAL_ERROR", 500);
      c.set("idempotencyCompleted", true);
      return c.json(response.data, 201);
    },
  );

  // FILE-051 delivery. Deliberately outside the JSON `/v1` catalogue: it
  // answers with file bytes, not a contract body. It is authenticated by the
  // router's auth middleware, and its authorization is the consume command
  // itself — which spends the single-use grant and then re-derives access
  // from *current* state through the same `file051_authorize_download` that
  // decides `file.download`. A leaked link is therefore not a standing
  // grant: it needs the recipient's own session, works once, expires in
  // minutes, and stops working the moment a publication is withdrawn, a
  // membership is revoked, or the object leaves `clean`.
  routes.get("/delivery/v1/files/:fileId/content", async (c) => {
    const delivery = deps.delivery;
    if (!delivery) return problem(c, "NOT_FOUND", 404);
    const fileId = c.req.param("fileId");
    const token = c.req.query("token");
    const queryKeys = Object.keys(c.req.queries());
    if (
      !UUID.test(fileId) || !token || queryKeys.length !== 1 ||
      c.req.queries("token")?.length !== 1
    ) {
      return problem(c, "DELIVERY_GRANT_INVALID", 404);
    }
    const payload = await verifyDeliveryToken(
      token,
      delivery.signingKey,
      fileId,
      Math.floor((delivery.now ?? Date.now)() / 1000),
    );
    const actor = c.get("actor");
    if (!payload || payload.userId !== actor.token.subject) {
      return problem(c, "DELIVERY_GRANT_INVALID", 404);
    }

    const result = await deps.repository.consumeDownloadGrant(
      {
        subject: actor.token.subject,
        schoolId: null,
        requestId: c.get("requestId"),
        aal2: actor.aal2,
      },
      fileId,
      await hashDeliveryNonce(payload.nonce),
    );
    if (result.outcome !== "ok" || !result.response) {
      return problem(
        c,
        result.outcome === "grant_invalid"
          ? "DELIVERY_GRANT_INVALID"
          : "NOT_FOUND",
        404,
      );
    }
    const effective = result.response;
    if (
      !effective.rootClean || !SHA256.test(effective.storedSha256 ?? "") ||
      !Number.isSafeInteger(effective.storedSizeBytes)
    ) {
      return problem(c, "NOT_FOUND", 404);
    }

    let bytes: Uint8Array;
    try {
      bytes = (await deps.storage.openObject(
        effective.bucket,
        effective.objectKey,
      )).bytes;
    } catch (error) {
      if (!(error instanceof StorageUnavailableError)) throw error;
      return problem(c, "STORAGE_UNAVAILABLE", 503);
    }
    // Serve only the exact bytes the scan recorded as stored.
    if (
      bytes.byteLength !== effective.storedSizeBytes ||
      await sha256Hex(bytes) !== effective.storedSha256
    ) {
      return problem(c, "STORAGE_UNAVAILABLE", 503);
    }

    return new Response(bytes, {
      status: 200,
      headers: {
        "Content-Type": safeMediaType(effective.mediaType),
        "Content-Length": String(bytes.byteLength),
        "Content-Disposition": contentDisposition(
          effective.displayName ?? "file",
        ),
        "Content-Security-Policy": "sandbox; default-src 'none'",
        "X-Content-Type-Options": "nosniff",
        "Cache-Control": "private, no-store",
        "Referrer-Policy": "no-referrer",
        "Cross-Origin-Resource-Policy": "same-origin",
      },
    });
  });

  return routes;
}

function deliveryUrl(base: string, fileId: string, token: string): string {
  const url = new URL(`/delivery/v1/files/${fileId}/content`, base);
  url.searchParams.set("token", token);
  return url.toString();
}

/** Only the four scanned types are ever served; anything else is opaque. */
function safeMediaType(value: string | null | undefined): string {
  return value === "application/pdf" || value === "image/jpeg" ||
      value === "image/png" || value === "image/webp"
    ? value
    : "application/octet-stream";
}

/** Always `attachment`; ASCII fallback plus RFC 5987 UTF-8 name. */
export function contentDisposition(displayName: string): string {
  const cleaned = normalizeDisplayName(displayName).replaceAll('"', "_");
  const ascii = cleaned.replace(/[^\x20-\x7e]/g, "_");
  const encoded = encodeURIComponent(cleaned).replace(
    /['()*]/g,
    (char) => `%${char.charCodeAt(0).toString(16).toUpperCase()}`,
  );
  return `attachment; filename="${ascii}"; filename*=UTF-8''${encoded}`;
}

function requestContext(c: Context<AuthorizationEnv>): RequestDbContext {
  return {
    subject: c.get("actor").token.subject,
    schoolId: c.get("authorization").tenant?.schoolId ?? null,
    requestId: c.get("requestId"),
    aal2: c.get("actor").aal2,
  };
}

function requiredParam(c: Context<AuthorizationEnv>, name: string): string {
  const value = validatedParams<Record<string, string>>(c as never)[name];
  if (!value) throw new Error(`validated route parameter missing: ${name}`);
  return value;
}

function mapOutcome(
  c: Context<AuthorizationEnv>,
  result: File050Result,
): Response | null {
  const mapped: Record<string, [ErrorCodeType, Parameters<typeof problem>[2]]> =
    {
      not_found: ["NOT_FOUND", 404],
      forbidden: ["FORBIDDEN", 403],
      invalid: ["INVALID_REQUEST", 400],
      invalid_state: ["INVALID_STATE", 409],
      size_limit: ["PAYLOAD_TOO_LARGE", 413],
      type_not_allowed: ["UNSUPPORTED_MEDIA_TYPE", 415],
      quota_exceeded: ["UPLOAD_QUOTA_EXCEEDED", 429],
      concurrency_limit: ["UPLOAD_CONCURRENCY_LIMIT", 429],
      expired: ["UPLOAD_EXPIRED", 409],
      already_completed: ["UPLOAD_ALREADY_COMPLETED", 409],
      incomplete: ["UPLOAD_INCOMPLETE", 409],
      file_not_clean: ["FILE_NOT_CLEAN", 409],
      delivery_disabled: ["FILE_DELIVERY_DISABLED", 409],
      grant_invalid: ["DELIVERY_GRANT_INVALID", 404],
    };
  if (result.outcome === "ok") return null;
  const entry = mapped[result.outcome] ?? ["INTERNAL_ERROR", 500];
  return problem(c, entry[0], entry[1]);
}

import { type Context, Hono } from "hono";
import {
  type ErrorCodeType,
  V1CreateUploadIntentRequest,
  v1Route,
} from "@studafy/contracts";
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
  StorageUnavailableError,
} from "./storage";

export interface FileRoutesDependencies {
  repository: FileRepository;
  storage: PrivateFileStorage;
  newIntentsEnabled: boolean;
}

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
      const result = await deps.repository.query(
        requestContext(c),
        download.operationId,
        id,
      );
      return mapOutcome(c, result) ?? problem(c, "FILE_DELIVERY_DISABLED", 409);
    },
  );

  return routes;
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
    };
  if (result.outcome === "ok") return null;
  const entry = mapped[result.outcome] ?? ["INTERNAL_ERROR", 500];
  return problem(c, entry[0], entry[1]);
}

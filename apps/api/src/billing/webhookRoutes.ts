import { Hono } from "hono";
import { sha256Hex } from "@studafy/infrastructure";
import type { Logger } from "@studafy/observability";
import type { AppEnv } from "../bootstrap/app";
import { problem } from "../platform/errors";
import type { AppleTransactionVerifier } from "./appleVerifier";
import type { GooglePurchaseVerifier } from "./googleVerifier";
import type { BillingRepository } from "./repository";

/**
 * Apple App Store Server Notifications V2 / Google Real-Time Developer
 * Notifications. The first unauthenticated `/v1`-adjacent routes in this
 * API: mounted directly on the top-level app, outside the auth-wrapped
 * router tree, with their own signature/OIDC verification standing in for
 * the bearer-JWT check every other route relies on.
 *
 * Both handlers do the minimum needed to durably record the event and ack
 * the provider fast: verify the signature/token, then hand off to
 * `private.billing_record_event` for dedupe. Re-verifying authoritative
 * state through the official API and deriving the ledger/entitlement change
 * happens in the worker (apps/worker/src/billing), decoupled from provider
 * or Redis availability at the moment the webhook arrives.
 */
export interface BillingWebhookDependencies {
  repository: BillingRepository;
  environment: string;
  apple: { verifier: AppleTransactionVerifier } | null;
  google: { verifier: GooglePurchaseVerifier } | null;
  logger: Logger;
}

export function createBillingWebhookRoutes(
  deps: BillingWebhookDependencies,
): Hono<AppEnv> {
  const routes = new Hono<AppEnv>();

  routes.post("/webhooks/apple", async (c) => {
    if (!deps.apple) return problem(c, "SERVICE_UNAVAILABLE", 503);
    const raw = await c.req.text();
    let body: { signedPayload?: unknown };
    try {
      body = JSON.parse(raw);
    } catch {
      return problem(c, "INVALID_REQUEST", 400);
    }
    if (typeof body.signedPayload !== "string" || !body.signedPayload) {
      return problem(c, "INVALID_REQUEST", 400);
    }
    let notificationUUID: string | null = null;
    try {
      const notification = await deps.apple.verifier.verifyNotification(
        body.signedPayload,
      );
      notificationUUID = notification.notificationUUID || null;
    } catch {
      // An unverifiable notification is never recorded or acted on. Apple
      // retries undelivered notifications, so a transient failure here
      // (e.g. a certificate rotation window) self-heals on redelivery.
      deps.logger.warn("billing_apple_webhook_rejected", {
        request_id: c.get("requestId"),
      });
      return problem(c, "RECEIPT_INVALID", 422);
    }
    const payloadHash = await sha256Hex(
      new TextEncoder().encode(body.signedPayload),
    );
    await deps.repository.recordEvent(
      "app_store",
      deps.environment,
      notificationUUID,
      payloadHash,
      body.signedPayload,
    );
    return c.json({ received: true }, 200);
  });

  routes.post("/webhooks/google", async (c) => {
    if (!deps.google) return problem(c, "SERVICE_UNAVAILABLE", 503);
    const authorized = await deps.google.verifier.verifyPubSubToken(
      c.req.header("authorization"),
    );
    if (!authorized) return problem(c, "FORBIDDEN", 403);
    const raw = await c.req.text();
    let body: { message?: { data?: unknown; messageId?: unknown } };
    try {
      body = JSON.parse(raw);
    } catch {
      return problem(c, "INVALID_REQUEST", 400);
    }
    const messageId = body.message?.messageId;
    const data = body.message?.data;
    if (typeof messageId !== "string" || typeof data !== "string") {
      return problem(c, "INVALID_REQUEST", 400);
    }
    let decoded: string;
    try {
      decoded = Buffer.from(data, "base64").toString("utf8");
    } catch {
      return problem(c, "INVALID_REQUEST", 400);
    }
    const payloadHash = await sha256Hex(new TextEncoder().encode(decoded));
    await deps.repository.recordEvent(
      "play_store",
      deps.environment,
      messageId,
      payloadHash,
      decoded,
    );
    return c.json({ received: true }, 200);
  });

  return routes;
}

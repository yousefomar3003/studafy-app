import { type Context, Hono } from "hono";
import {
  V1RestorePurchaseRequest,
  V1SetSelfPurchaseRequest,
  V1SubmitPurchaseRequest,
  v1Route,
} from "@studafy/contracts";
import {
  isAppleTransactionTrusted,
  isGooglePackageNameTrusted,
  issueParentalGateChallenge,
  mapAppleTransactionTypeToState,
  mapGoogleSubscriptionStateToTransactionState,
  verifyParentalGateAnswer,
} from "@studafy/domain";
import { sha256Hex } from "@studafy/infrastructure";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import { requirePermission } from "../authorization/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { idempotency } from "../platform/idempotency";
import { problem } from "../platform/errors";
import { validatedBody, validateRouteInput } from "../platform/validation";
import type { RequestDbContext } from "../platform/catalogueRoutes";
import type { AppleTransactionVerifier } from "./appleVerifier";
import { AppleVerificationError } from "./appleVerifier";
import type { GooglePurchaseVerifier } from "./googleVerifier";
import { GoogleVerificationError } from "./googleVerifier";
import type { BillingRepository, NormalizedTransaction } from "./repository";

export interface BillingRoutesDependencies {
  repository: BillingRepository;
  environment: string;
  apple: {
    verifier: AppleTransactionVerifier;
    bundleId: string;
    platformEnvironment: "Sandbox" | "Production";
  } | null;
  google: {
    verifier: GooglePurchaseVerifier;
    packageName: string;
  } | null;
  parentalGateSigningKey: string;
}

export function createBillingRoutes(
  deps: BillingRoutesDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const parentalGate = v1Route("getParentalGateChallenge");
  const catalogue = v1Route("getBillingCatalogue");
  const submit = v1Route("submitPurchase");
  const restore = v1Route("restorePurchase");
  const entitlements = v1Route("listEntitlements");
  const setSelfPurchase = v1Route("setSelfPurchase");

  routes.get(
    "/v1/billing/parental-gate",
    validateRouteInput(parentalGate) as never,
    requirePermission(authorization, "billing.purchase.submit"),
    async (c) => {
      const challenge = await issueParentalGateChallenge(
        deps.parentalGateSigningKey,
      );
      return c.json(challenge);
    },
  );

  routes.get(
    "/v1/billing/catalogue",
    validateRouteInput(catalogue) as never,
    requirePermission(authorization, "billing.catalogue.read"),
    async (c) => {
      const [products, selfPurchase] = await Promise.all([
        deps.repository.catalogue(deps.environment),
        deps.repository.selfPurchaseStatus(requestContext(c)),
      ]);
      return c.json({ products: products.products, selfPurchase });
    },
  );

  routes.post(
    "/v1/billing/purchases",
    validateRouteInput(submit) as never,
    requirePermission(authorization, "billing.purchase.submit"),
    idempotency(idempotencyDependencies, submit.operationId, "required"),
    async (c) => {
      const reservation = c.get("idempotencyReservation");
      if (!reservation) return problem(c, "FORBIDDEN", 403);
      const body = V1SubmitPurchaseRequest.parse(validatedBody(c as never));

      if (body.parentalGate) {
        const confirmed = await verifyParentalGateAnswer(
          body.parentalGate.token,
          body.parentalGate.answer,
          deps.parentalGateSigningKey,
        );
        if (!confirmed) return problem(c, "PARENTAL_GATE_REQUIRED", 403);
      }

      let normalized: NormalizedTransaction;
      try {
        normalized = await verifyAndNormalize(body, deps);
      } catch (error) {
        if (
          error instanceof AppleVerificationError ||
          error instanceof GoogleVerificationError
        ) {
          return problem(c, "RECEIPT_INVALID", 422);
        }
        if (error instanceof VerifierUnavailableError) {
          return problem(c, "SERVICE_UNAVAILABLE", 503);
        }
        throw error;
      }
      normalized.beneficiaryStudentId = body.beneficiaryStudentId ?? null;
      normalized.parentalGateConfirmed = Boolean(body.parentalGate);

      const result = await deps.repository.submitVerification(
        requestContext(c),
        normalized,
      );
      const failure = mapBillingOutcome(c, result.outcome);
      if (failure) return failure;

      // Google auto-refunds an unacknowledged purchase after 3 days; ack
      // inline on the happy path so the common case never depends on the
      // reconciliation sweep. A failure here is not fatal to the response -
      // the sweep retries it.
      if (body.platform === "play_store" && deps.google) {
        await deps.google.verifier.acknowledgeSubscription(
          deps.google.packageName,
          body.verificationPayload,
        ).catch(() => undefined);
      }

      c.set("idempotencyCompleted", true);
      return c.json(result.response, 200);
    },
  );

  routes.post(
    "/v1/billing/restore",
    validateRouteInput(restore) as never,
    requirePermission(authorization, "billing.restore"),
    idempotency(idempotencyDependencies, restore.operationId, "required"),
    async (c) => {
      const reservation = c.get("idempotencyReservation");
      if (!reservation) return problem(c, "FORBIDDEN", 403);
      const body = V1RestorePurchaseRequest.parse(validatedBody(c as never));

      let normalized: NormalizedTransaction;
      try {
        normalized = await verifyAndNormalize(body, deps);
      } catch (error) {
        if (
          error instanceof AppleVerificationError ||
          error instanceof GoogleVerificationError
        ) {
          return problem(c, "RECEIPT_INVALID", 422);
        }
        if (error instanceof VerifierUnavailableError) {
          return problem(c, "SERVICE_UNAVAILABLE", 503);
        }
        throw error;
      }
      normalized.beneficiaryStudentId = body.beneficiaryStudentId ?? null;
      normalized.parentalGateConfirmed = Boolean(body.parentalGate);

      const result = await deps.repository.restore(
        requestContext(c),
        normalized,
      );
      const failure = mapBillingOutcome(c, result.outcome);
      if (failure) return failure;
      c.set("idempotencyCompleted", true);
      const response = result.response as { restored?: boolean } | undefined;
      return c.json(
        { restored: true, ...(response ?? {}) },
        200,
      );
    },
  );

  routes.get(
    "/v1/billing/entitlements",
    validateRouteInput(entitlements) as never,
    requirePermission(authorization, "billing.entitlement.read"),
    async (c) => {
      const rows = await deps.repository.listEntitlements(requestContext(c));
      return c.json({ entitlements: rows });
    },
  );

  routes.post(
    "/v1/billing/school-settings/self-purchase",
    validateRouteInput(setSelfPurchase) as never,
    requirePermission(authorization, "billing.school_settings.write"),
    idempotency(idempotencyDependencies, setSelfPurchase.operationId, "required"),
    async (c) => {
      const reservation = c.get("idempotencyReservation");
      if (!reservation) return problem(c, "FORBIDDEN", 403);
      const body = V1SetSelfPurchaseRequest.parse(validatedBody(c as never));
      const ok = await deps.repository.setSelfPurchase(
        requestContext(c),
        body.schoolId,
        body.enabled,
      );
      if (!ok) return problem(c, "FORBIDDEN", 403);
      c.set("idempotencyCompleted", true);
      return c.json({ schoolId: body.schoolId, selfPurchaseEnabled: body.enabled });
    },
  );

  return routes;
}

class VerifierUnavailableError extends Error {}

async function verifyAndNormalize(
  body: {
    platform: "app_store" | "play_store";
    environment: string;
    productFeatureKey: string;
    storeProductId: string;
    verificationPayload: string;
  },
  deps: BillingRoutesDependencies,
): Promise<NormalizedTransaction> {
  const signedDataHash = await sha256Hex(
    new TextEncoder().encode(body.verificationPayload),
  );

  if (body.platform === "app_store") {
    if (!deps.apple) throw new VerifierUnavailableError();
    const decoded = await deps.apple.verifier.verifyTransaction(
      body.verificationPayload,
    );
    if (
      !isAppleTransactionTrusted({
        bundleId: decoded.bundleId,
        expectedBundleId: deps.apple.bundleId,
        environment: decoded.environment,
        expectedEnvironment: deps.apple.platformEnvironment,
      }) || decoded.productId !== body.storeProductId
    ) {
      throw new AppleVerificationError("bundle, environment or product mismatch");
    }
    const state = mapAppleTransactionTypeToState(
      null,
      decoded.revocationReason,
      decoded.expiresDate,
      Date.now(),
    );
    return {
      platform: "app_store",
      environment: body.environment,
      productFeatureKey: body.productFeatureKey,
      storeProductId: body.storeProductId,
      originalTransactionId: decoded.originalTransactionId,
      transactionId: decoded.transactionId,
      signedDataHash,
      state,
      purchasedAt: new Date(decoded.purchaseDate).toISOString(),
      effectiveUntil: decoded.expiresDate
        ? new Date(decoded.expiresDate).toISOString()
        : null,
    };
  }

  if (!deps.google) throw new VerifierUnavailableError();
  const verified = await deps.google.verifier.verifySubscription(
    deps.google.packageName,
    body.verificationPayload,
  );
  if (
    !isGooglePackageNameTrusted(verified.packageName, deps.google.packageName) ||
    verified.productId !== body.storeProductId
  ) {
    throw new GoogleVerificationError("package name or product mismatch");
  }
  const state = mapGoogleSubscriptionStateToTransactionState(
    verified.subscriptionState,
  ) ?? "on_hold";
  return {
    platform: "play_store",
    environment: body.environment,
    productFeatureKey: body.productFeatureKey,
    storeProductId: body.storeProductId,
    originalTransactionId: verified.originalTransactionId,
    transactionId: verified.transactionId,
    signedDataHash,
    state,
    purchasedAt: verified.startTime ?? new Date().toISOString(),
    effectiveUntil: verified.expiryTime,
  };
}

function requestContext(c: Context<AuthorizationEnv>): RequestDbContext {
  return {
    subject: c.get("actor").token.subject,
    schoolId: c.get("authorization").tenant?.schoolId ?? null,
    requestId: c.get("requestId"),
    aal2: c.get("actor").aal2,
  };
}

function mapBillingOutcome(
  c: Context<AuthorizationEnv>,
  outcome: string,
): Response | null {
  if (outcome === "ok") return null;
  const mapped: Record<string, Parameters<typeof problem>[1]> = {
    forbidden: "FORBIDDEN",
    product_not_found: "PRODUCT_NOT_FOUND",
    beneficiary_required: "BENEFICIARY_LINK_INVALID",
    beneficiary_link_invalid: "BENEFICIARY_LINK_INVALID",
    invalid_beneficiary: "BENEFICIARY_LINK_INVALID",
    not_eligible: "FORBIDDEN",
    parental_gate_required: "PARENTAL_GATE_REQUIRED",
    student_purchase_disabled: "STUDENT_PURCHASE_DISABLED",
    owned_by_other_account: "ENTITLEMENT_OWNED_BY_OTHER_ACCOUNT",
  };
  const code = mapped[outcome] ?? "INTERNAL_ERROR";
  const status = code === "INTERNAL_ERROR"
    ? 500
    : code === "FORBIDDEN" || code === "ENTITLEMENT_OWNED_BY_OTHER_ACCOUNT"
    ? 403
    : code === "PRODUCT_NOT_FOUND"
    ? 404
    : 422;
  return problem(c, code, status);
}

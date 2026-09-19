import { type Context, Hono, type MiddlewareHandler } from "hono";
import {
  V1DecidePurchaseApprovalRequest,
  V1RequestPurchaseApprovalRequest,
  V1RestorePurchaseRequest,
  v1Route,
  V1SetSelfPurchaseRequest,
  V1SubmitPurchaseRequest,
} from "@studafy/contracts";
import {
  isAppleTransactionTrusted,
  isGooglePackageNameTrusted,
  mapAppleTransactionTypeToState,
  mapGoogleSubscriptionStateToTransactionState,
} from "@studafy/domain";
import { sha256Hex } from "@studafy/infrastructure";
import type {
  AuthorizationDependencies,
  AuthorizationEnv,
} from "../authorization/middleware";
import { requirePermission } from "../authorization/middleware";
import type { AuthDependencies } from "../auth/middleware";
import { requireRecentAuth } from "../auth/middleware";
import type { IdempotencyDependencies } from "../platform/idempotency";
import { idempotency } from "../platform/idempotency";
import { problem } from "../platform/errors";
import {
  validatedBody,
  validatedParams,
  validateRouteInput,
} from "../platform/validation";
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
}

export function createBillingRoutes(
  deps: BillingRoutesDependencies,
  authorization: AuthorizationDependencies,
  idempotencyDependencies: IdempotencyDependencies,
  authDependencies: AuthDependencies,
): Hono<AuthorizationEnv> {
  const routes = new Hono<AuthorizationEnv>();
  const requestApproval = v1Route("requestPurchaseApproval");
  const listApprovals = v1Route("listPurchaseApprovals");
  const decideApproval = v1Route("decidePurchaseApproval");
  const catalogue = v1Route("getBillingCatalogue");
  const submit = v1Route("submitPurchase");
  const restore = v1Route("restorePurchase");
  const entitlements = v1Route("listEntitlements");
  const setSelfPurchase = v1Route("setSelfPurchase");

  // DL-048: a student self-purchase needs a guardian's approval, decided in
  // the guardian's own session behind a fresh recent-auth challenge. This
  // replaces the arithmetic challenge a child could answer unaided.
  routes.post(
    "/v1/billing/purchase-approvals",
    validateRouteInput(requestApproval) as never,
    requirePermission(authorization, "billing.purchase_approval.request"),
    idempotency(
      idempotencyDependencies,
      requestApproval.operationId,
      "required",
    ),
    async (c) => {
      const reservation = c.get("idempotencyReservation");
      if (!reservation) return problem(c, "FORBIDDEN", 403);
      const body = V1RequestPurchaseApprovalRequest.parse(
        validatedBody(c as never),
      );
      const result = await deps.repository.requestPurchaseApproval(
        requestContext(c),
        body.featureKey,
        reservation,
      );
      const failure = mapBillingOutcome(c, result.outcome);
      if (failure) return failure;
      c.set("idempotencyCompleted", true);
      return c.json(result.response, 201);
    },
  );

  routes.get(
    "/v1/billing/purchase-approvals",
    validateRouteInput(listApprovals) as never,
    requirePermission(authorization, "billing.purchase_approval.read"),
    async (c) => {
      const approvals = await deps.repository.listPurchaseApprovals(
        requestContext(c),
      );
      return c.json({ approvals });
    },
  );

  routes.post(
    "/v1/billing/purchase-approvals/:approvalId/decision",
    validateRouteInput(decideApproval) as never,
    requirePermission(authorization, "billing.purchase_approval.decide"),
    idempotency(
      idempotencyDependencies,
      decideApproval.operationId,
      "required",
    ),
    requireRecentAuth(
      authDependencies,
      "billing_purchase_approval",
    ) as unknown as MiddlewareHandler<AuthorizationEnv>,
    async (c) => {
      const reservation = c.get("idempotencyReservation");
      if (!reservation) return problem(c, "FORBIDDEN", 403);
      const { approvalId } = validatedParams<{ approvalId: string }>(
        c as never,
      );
      const body = V1DecidePurchaseApprovalRequest.parse(
        validatedBody(c as never),
      );
      const result = await deps.repository.decidePurchaseApproval(
        requestContext(c),
        approvalId,
        body.approve,
        reservation,
      );
      const failure = mapBillingOutcome(c, result.outcome);
      if (failure) return failure;
      c.set("idempotencyCompleted", true);
      return c.json(result.response, 200);
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
      return c.json({
        products: products.products,
        selfPurchase,
        purchaseAccountToken: c.get("actor").token.subject,
      });
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

      let normalized: NormalizedTransaction;
      try {
        normalized = await verifyAndNormalize(
          body,
          deps,
          c.get("actor").token.subject,
        );
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

      const result = await deps.repository.submitVerification(
        requestContext(c),
        normalized,
        reservation,
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
        normalized = await verifyAndNormalize(
          body,
          deps,
          c.get("actor").token.subject,
        );
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

      const result = await deps.repository.restore(
        requestContext(c),
        normalized,
        reservation,
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
      const rows = await deps.repository.listEntitlements(
        requestContext(c),
        deps.environment,
      );
      return c.json({ entitlements: rows });
    },
  );

  routes.post(
    "/v1/billing/school-settings/self-purchase",
    validateRouteInput(setSelfPurchase) as never,
    requirePermission(authorization, "billing.school_settings.write"),
    idempotency(
      idempotencyDependencies,
      setSelfPurchase.operationId,
      "required",
    ),
    async (c) => {
      const reservation = c.get("idempotencyReservation");
      if (!reservation) return problem(c, "FORBIDDEN", 403);
      const body = V1SetSelfPurchaseRequest.parse(validatedBody(c as never));
      const ok = await deps.repository.setSelfPurchase(
        requestContext(c),
        body.schoolId,
        body.enabled,
        reservation,
      );
      if (!ok) return problem(c, "FORBIDDEN", 403);
      c.set("idempotencyCompleted", true);
      return c.json({
        schoolId: body.schoolId,
        selfPurchaseEnabled: body.enabled,
      });
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
  subject: string,
): Promise<NormalizedTransaction> {
  if (body.environment !== deps.environment) {
    throw new AppleVerificationError("billing environment mismatch");
  }
  const signedDataHash = await sha256Hex(
    new TextEncoder().encode(body.verificationPayload),
  );

  if (body.platform === "app_store") {
    if (!deps.apple) throw new VerifierUnavailableError();
    const receipt = await deps.apple.verifier.verifyTransaction(
      body.verificationPayload,
    );
    const decoded = await deps.apple.verifier.getSubscriptionStatus(
      receipt.originalTransactionId,
    );
    if (
      !decoded ||
      decoded.originalTransactionId !== receipt.originalTransactionId ||
      decoded.appAccountToken !== subject ||
      receipt.appAccountToken !== subject ||
      (decoded.environment === "Production") !==
        (deps.environment === "production")
    ) {
      throw new AppleVerificationError(
        "subscription ownership or environment mismatch",
      );
    }
    if (
      !isAppleTransactionTrusted({
        bundleId: decoded.bundleId,
        expectedBundleId: deps.apple.bundleId,
        environment: decoded.environment,
        expectedEnvironment: deps.apple.platformEnvironment,
      }) || decoded.productId !== body.storeProductId
    ) {
      throw new AppleVerificationError(
        "bundle, environment or product mismatch",
      );
    }
    const state = mapAppleTransactionTypeToState(
      null,
      decoded.revocationReason,
      decoded.expiresDate,
      Date.now(),
    );
    return {
      platform: "app_store",
      environment: deps.environment,
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
    !isGooglePackageNameTrusted(
      verified.packageName,
      deps.google.packageName,
    ) ||
    verified.productId !== body.storeProductId ||
    verified.obfuscatedExternalAccountId !== subject ||
    verified.testPurchase !== (deps.environment !== "production")
  ) {
    throw new GoogleVerificationError("package name or product mismatch");
  }
  const state = mapGoogleSubscriptionStateToTransactionState(
    verified.subscriptionState,
  ) ?? "on_hold";
  return {
    platform: "play_store",
    environment: deps.environment,
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
    guardian_link_required: "GUARDIAN_LINK_REQUIRED",
    not_found: "NOT_FOUND",
    invalid_state: "INVALID_STATE",
    student_purchase_disabled: "STUDENT_PURCHASE_DISABLED",
    owned_by_other_account: "ENTITLEMENT_OWNED_BY_OTHER_ACCOUNT",
  };
  const code = mapped[outcome] ?? "INTERNAL_ERROR";
  const status = code === "INTERNAL_ERROR"
    ? 500
    : code === "FORBIDDEN" || code === "ENTITLEMENT_OWNED_BY_OTHER_ACCOUNT"
    ? 403
    : code === "PRODUCT_NOT_FOUND" || code === "NOT_FOUND"
    ? 404
    : code === "INVALID_STATE"
    ? 409
    : 422;
  return problem(c, code, status);
}

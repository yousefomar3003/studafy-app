import { z } from "zod";

const Id = z.string().uuid();
const Timestamp = z.string().datetime({ offset: true });

/**
 * PAY-071. Two platforms. `student_ai` and `teacher_ai_grading` are retired
 * ledger vocabulary: AI-072 removed the AI capability (ADR-0026), so neither
 * is offered in any environment and the database forbids activating either.
 * They remain here only so historical ledger rows stay decodable.
 * `parent_insights` stays out of the catalogue everywhere but `synthetic`
 * until the §29 legal sign-off lands.
 */
export const V1BillingFeatureKey = z.enum([
  "parent_insights",
  "student_notebook",
  "student_ai",
  "teacher_ai_grading",
]);
export type V1BillingFeatureKey = z.infer<typeof V1BillingFeatureKey>;

export const V1BillingPlatform = z.enum(["app_store", "play_store"]);
export type V1BillingPlatform = z.infer<typeof V1BillingPlatform>;

export const V1BillingEnvironment = z.enum([
  "synthetic",
  "development",
  "staging",
  "production",
]);
export type V1BillingEnvironment = z.infer<typeof V1BillingEnvironment>;

export const V1BillingEntitlementStatus = z.enum([
  "pending",
  "active",
  "grace_period",
  "on_hold",
  "revoked",
  "expired",
]);
export type V1BillingEntitlementStatus = z.infer<
  typeof V1BillingEntitlementStatus
>;

export const V1BillingProduct = z.strictObject({
  featureKey: V1BillingFeatureKey,
  platform: V1BillingPlatform,
  storeProductId: z.string().min(1).max(200),
});
export type V1BillingProduct = z.infer<typeof V1BillingProduct>;

export const V1BillingSelfPurchaseStatus = z.strictObject({
  schoolId: Id,
  selfPurchaseEnabled: z.boolean(),
});
export type V1BillingSelfPurchaseStatus = z.infer<
  typeof V1BillingSelfPurchaseStatus
>;

export const V1BillingCatalogueResponse = z.strictObject({
  purchaseAccountToken: Id,
  products: z.array(V1BillingProduct).max(16),
  selfPurchase: z.array(V1BillingSelfPurchaseStatus).max(16),
});
export type V1BillingCatalogueResponse = z.infer<
  typeof V1BillingCatalogueResponse
>;

/**
 * `verificationPayload` is whatever `in_app_purchase`'s
 * `PurchaseDetails.verificationData.serverVerificationData` contains: a
 * signed JWSTransaction for Apple, a purchase-token JSON blob for Google.
 * The server verifies it against the official provider API before trusting
 * any field inside it - nothing here is trusted client input except "please
 * check this opaque blob".
 */
/**
 * Guardian purchase approval (audit follow-up, DL-048). A student
 * self-purchase is verified only when a guardian holding a verified,
 * unexpired link has approved it from their own session after a
 * recent-auth challenge. The server consumes the approval when it records
 * the subscription's first ledger row; the client never asserts it.
 */
export const V1PurchaseApprovalFeatureKey = z.enum(["student_notebook"]);
export const V1PurchaseApprovalStatus = z.enum([
  "requested",
  "approved",
  "declined",
  "consumed",
  "expired",
]);

export const V1PurchaseApproval = z.strictObject({
  id: Id,
  studentId: Id,
  studentName: z.string().min(1).max(200),
  featureKey: V1PurchaseApprovalFeatureKey,
  status: V1PurchaseApprovalStatus,
  requestedAt: Timestamp,
  decidedAt: Timestamp.nullable(),
  expiresAt: Timestamp,
});
export type V1PurchaseApproval = z.infer<typeof V1PurchaseApproval>;

export const V1RequestPurchaseApprovalRequest = z.strictObject({
  featureKey: V1PurchaseApprovalFeatureKey,
});
export type V1RequestPurchaseApprovalRequest = z.infer<
  typeof V1RequestPurchaseApprovalRequest
>;

export const V1PurchaseApprovalsResponse = z.strictObject({
  approvals: z.array(V1PurchaseApproval).max(50),
});
export type V1PurchaseApprovalsResponse = z.infer<
  typeof V1PurchaseApprovalsResponse
>;

export const V1DecidePurchaseApprovalRequest = z.strictObject({
  approve: z.boolean(),
});
export type V1DecidePurchaseApprovalRequest = z.infer<
  typeof V1DecidePurchaseApprovalRequest
>;

export const V1SubmitPurchaseRequest = z.strictObject({
  platform: V1BillingPlatform,
  environment: V1BillingEnvironment,
  productFeatureKey: V1BillingFeatureKey,
  storeProductId: z.string().min(1).max(200),
  verificationPayload: z.string().min(1).max(16_384),
  beneficiaryStudentId: Id.optional(),
});
export type V1SubmitPurchaseRequest = z.infer<typeof V1SubmitPurchaseRequest>;

export const V1SubmitPurchaseResponse = z.strictObject({
  featureKey: V1BillingFeatureKey,
  derivation: z.enum([
    "granted",
    "updated",
    "pending",
    "duplicate_entitlement",
  ]),
});
export type V1SubmitPurchaseResponse = z.infer<
  typeof V1SubmitPurchaseResponse
>;

export const V1RestorePurchaseRequest = V1SubmitPurchaseRequest;
export type V1RestorePurchaseRequest = z.infer<
  typeof V1RestorePurchaseRequest
>;

export const V1RestorePurchaseResponse = z.strictObject({
  restored: z.boolean(),
  featureKey: V1BillingFeatureKey.optional(),
  derivation: z.enum(["granted", "updated", "pending", "duplicate_entitlement"])
    .optional(),
});
export type V1RestorePurchaseResponse = z.infer<
  typeof V1RestorePurchaseResponse
>;

export const V1Entitlement = z.strictObject({
  featureKey: V1BillingFeatureKey,
  status: V1BillingEntitlementStatus,
  startsAt: Timestamp,
  endsAt: Timestamp.nullable(),
  /**
   * Null for the caller's own entitlement. Set to a linked child's student id
   * when a guardian reads the Parent Insights entitlement attached to that
   * child (ADR-0009: the beneficiary, not the purchaser, holds access).
   */
  beneficiaryStudentId: Id.nullable(),
});
export type V1Entitlement = z.infer<typeof V1Entitlement>;

export const V1EntitlementsResponse = z.strictObject({
  entitlements: z.array(V1Entitlement).max(32),
});
export type V1EntitlementsResponse = z.infer<typeof V1EntitlementsResponse>;

/** ADR-0009's per-school student self-purchase switch. Default off. */
export const V1SetSelfPurchaseRequest = z.strictObject({
  schoolId: Id,
  enabled: z.boolean(),
});
export type V1SetSelfPurchaseRequest = z.infer<
  typeof V1SetSelfPurchaseRequest
>;

export const V1SetSelfPurchaseResponse = V1BillingSelfPurchaseStatus;
export type V1SetSelfPurchaseResponse = z.infer<
  typeof V1SetSelfPurchaseResponse
>;

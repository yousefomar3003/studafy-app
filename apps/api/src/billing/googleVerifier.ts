/**
 * Google Play Developer API / RTDN verification, shared with the worker
 * (PAY-071). The implementation lives in `@studafy/infrastructure` so the
 * client purchase path and the webhook re-verification path use exactly the
 * same verifier; this file is a thin re-export that keeps the old import site
 * stable.
 */
export {
  type GooglePurchaseVerifier,
  GoogleVerificationError,
  type GoogleVerifierConfig,
  RealGooglePurchaseVerifier,
  type VerifiedGooglePurchase,
} from "@studafy/infrastructure";

/**
 * Store notification plumbing that is set up by hand in the store consoles
 * rather than read from the environment. The setup docs name these values
 * (docs/deployment/subscriptions.md and the owner guide
 * docs/guides/owner/05-play-billing.md); packages/config/test/storeWebhooks.test.ts
 * pins them to the docs so the two cannot drift apart.
 */

/** App Store Server Notifications V2 endpoint on the API. */
export const APP_STORE_NOTIFICATIONS_PATH = "/webhooks/apple";

/**
 * Google Play Real-Time Developer Notifications push endpoint on the API.
 * The Pub/Sub push subscription calls `https://<api-host>` + this path, and
 * `GOOGLE_PUBSUB_AUDIENCE` must be that exact URL: the API checks the push
 * request's OIDC token against it.
 */
export const PLAY_BILLING_PUSH_PATH = "/webhooks/google";

/**
 * The Pub/Sub topic id the Play Console publishes RTDN messages to
 * (`projects/<cloud-project>/topics/play-billing`). Nothing at runtime reads
 * it: a push request names its subscription, not its topic. It is here so
 * the documented name has one source.
 */
export const PLAY_BILLING_PUBSUB_TOPIC_ID = "play-billing";

/**
 * Whether a configured `GOOGLE_PUBSUB_AUDIENCE` is a URL for the push
 * endpoint. `null` when it is not set. A mismatch means every Play
 * notification is refused with 403, so the startup log reports it.
 */
export function pubSubAudienceMatchesPushPath(
  audience: string | undefined,
): boolean | null {
  if (!audience) return null;
  try {
    const parsed = new URL(audience);
    return parsed.protocol === "https:" &&
      parsed.pathname === PLAY_BILLING_PUSH_PATH && !parsed.search &&
      !parsed.hash;
  } catch {
    return false;
  }
}

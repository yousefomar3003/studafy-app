/**
 * Time limit for one call to a store API (Google Play Developer API, App
 * Store Server API), token and certificate fetches included. Neither
 * client library sets one, so a connection that stops answering would hold
 * the webhook request, the billing job or the reconciliation sweep for
 * good (worker stall review, 2026-10-20).
 */
export const STORE_API_TIMEOUT_MS = 20_000;

/**
 * Settles with `work`, or rejects once `ms` pass. The message says
 * "timeout", which the worker's error normalisation reads as
 * DEPENDENCY_UNAVAILABLE (retry later). `work` itself is not cancelled.
 */
export async function withDeadline<T>(
  work: Promise<T>,
  ms: number,
  what: string,
): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      work,
      new Promise<never>((_, reject) => {
        timer = setTimeout(
          () => reject(new Error(`${what}: timeout after ${ms} ms`)),
          ms,
        );
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}

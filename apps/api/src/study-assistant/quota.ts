import type { Redis } from "@studafy/infrastructure";
import { hmacSubject } from "../platform/rate-limit/policies";
import type { StudyAssistantQuota } from "./routes";

/**
 * A per-account daily allowance for the study assistant.
 *
 * Distinct from the rate limiter, which smooths bursts. This is a spend
 * ceiling: the provider charges per call, so without a hard daily cap one
 * account - or one script holding a valid token - is an open invoice.
 *
 * Keyed by HMAC of the subject, never the raw user id, so the cache cannot
 * be read as a list of who used the assistant today.
 *
 * Fails CLOSED. Every other cache in this codebase falls back to the source
 * of truth when Redis is unreachable, but there is no source of truth for
 * "how much have we spent today" - so an outage must not become unlimited
 * spending on children's questions going to a third party.
 */
export function createStudyAssistantQuota(options: {
  redis: Redis;
  signingKey: string;
  dailyLimit: number;
  now?: () => Date;
}): StudyAssistantQuota {
  const { redis, signingKey, dailyLimit, now = () => new Date() } = options;

  return {
    async consume(subject: string): Promise<number | null> {
      const day = now().toISOString().slice(0, 10);
      const key = `studafy:ai-quota:${day}:${
        hmacSubject(signingKey, "aiquota", subject)
      }`;
      try {
        const used = await redis.incr(key);
        if (used === 1) {
          // Expire a little after the day ends so a clock skew cannot leave
          // an account with two allowances.
          await redis.expire(key, 60 * 60 * 26);
        }
        if (used > dailyLimit) return null;
        return dailyLimit - used;
      } catch {
        return null;
      }
    },
  };
}

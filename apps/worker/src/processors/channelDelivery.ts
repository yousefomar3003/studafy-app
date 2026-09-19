import type { Sql } from "@studafy/database";
import type { Logger } from "@studafy/observability";
import {
  ChannelSendError,
  type EmailSender,
  type PushSender,
} from "@studafy/infrastructure";
import { channelCopy } from "./notificationCopy";

interface ChannelJob {
  deliveryId: number;
  templateKey: string;
  locale: string;
  email?: string | null;
  tokens?: string[] | null;
}

export interface ChannelDeliveryRuntime {
  close(): Promise<void>;
  /** Fans out, then sends due email and push; returns deliveries sent. */
  runOnce(): Promise<number>;
}

/**
 * DL-053 email/push delivery. Each pass fans recent in-app notifications
 * out to the channels their recipients allow, then sends due deliveries on
 * every channel that has a configured sender. A channel without a sender is
 * never claimed, so its deliveries wait rather than fail. Logs carry ids and
 * outcomes, never addresses, tokens or copy.
 */
export function startChannelDelivery(
  sql: Sql,
  senders: { email?: EmailSender; push?: PushSender },
  logger: Logger,
  intervalMs = 10_000,
): ChannelDeliveryRuntime {
  let closed = false;
  let running: Promise<number> | null = null;

  const finish = async (
    job: ChannelJob,
    success: boolean,
    error: ChannelSendError | null,
    providerMessageId: string | null,
  ): Promise<string> => {
    const rows = await sql<{ outcome: string }[]>`
      select private.channel_finish(
        ${job.deliveryId}, ${success}, ${error?.code ?? null},
        ${error?.terminal ?? false}, ${providerMessageId}
      ) as outcome
    `;
    return rows[0]?.outcome ?? "lost";
  };

  const asSendError = (error: unknown) =>
    error instanceof ChannelSendError
      ? error
      : new ChannelSendError("SENDER_ERROR", false);

  const sendEmail = async (sender: EmailSender, job: ChannelJob) => {
    if (!job.email) {
      return await finish(
        job,
        false,
        new ChannelSendError("NO_ADDRESS", true),
        null,
      );
    }
    const text = channelCopy(job.templateKey, job.locale);
    try {
      const sent = await sender.send({
        to: job.email,
        subject: text.title,
        text: `${text.body}\n\nOpen Studafy to see it.`,
      });
      return await finish(job, true, null, sent.providerMessageId);
    } catch (error) {
      return await finish(job, false, asSendError(error), null);
    }
  };

  const sendPush = async (sender: PushSender, job: ChannelJob) => {
    const tokens = job.tokens ?? [];
    if (tokens.length === 0) {
      return await finish(
        job,
        false,
        new ChannelSendError("NO_DEVICE", true),
        null,
      );
    }
    const text = channelCopy(job.templateKey, job.locale);
    let delivered: string | null = null;
    let lastError: ChannelSendError | null = null;
    let anyRetryable = false;
    for (const token of tokens) {
      try {
        const sent = await sender.send({
          token,
          title: text.title,
          body: text.body,
          data: { templateKey: job.templateKey },
        });
        delivered ??= sent.providerMessageId ?? "sent";
      } catch (error) {
        lastError = asSendError(error);
        if (lastError.invalidTarget) {
          await sql`select private.push_device_revoke_token(${token})`;
        } else if (!lastError.terminal) {
          anyRetryable = true;
        }
      }
    }
    if (delivered) return await finish(job, true, null, delivered);
    return await finish(
      job,
      false,
      new ChannelSendError(lastError?.code ?? "SENDER_ERROR", !anyRetryable),
      null,
    );
  };

  const runOnce = async (): Promise<number> => {
    if (closed) return 0;
    await sql`select private.channel_fanout(200)`;
    let sent = 0;
    for (const channel of ["email", "push"] as const) {
      const sender = senders[channel];
      if (!sender) continue;
      const rows = await sql<{ jobs: ChannelJob[] }[]>`
        select private.channel_claim(${channel}, 20) as jobs
      `;
      for (const job of rows[0]?.jobs ?? []) {
        const outcome = channel === "email"
          ? await sendEmail(sender as EmailSender, job)
          : await sendPush(sender as PushSender, job);
        if (outcome === "sent") sent++;
        logger.info("channel_delivery", {
          channel,
          delivery_id: job.deliveryId,
          outcome,
        });
      }
    }
    return sent;
  };

  const tick = () => {
    if (running) return;
    running = runOnce().catch((error) => {
      logger.error("channel_delivery_poll_failed", {
        error_name: error instanceof Error ? error.name : "unknown",
      });
      return 0;
    }).finally(() => running = null);
  };
  const timer = setInterval(tick, intervalMs);
  tick();

  return {
    runOnce,
    async close() {
      closed = true;
      clearInterval(timer);
      await running;
    },
  };
}

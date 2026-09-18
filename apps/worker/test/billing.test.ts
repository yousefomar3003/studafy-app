import { describe, expect, test } from "bun:test";
import type {
  AppleTransactionVerifier,
  GooglePurchaseVerifier,
  VerifiedAppleNotification,
  VerifiedAppleTransaction,
  VerifiedGooglePurchase,
} from "@studafy/infrastructure";
import type { Queue } from "@studafy/infrastructure";
import { createJsonLogger } from "@studafy/observability";
import { LogCollector } from "@studafy/test-support";
import type { Job, JobsOptions } from "bullmq";
import {
  type BillingDispatchPort,
  billingEventIdFromJobId,
  billingEventJobId,
  type BillingEventPayload,
  type BillingFinishOutcome,
  type ClaimedBillingEvent,
  type ReconciliationCandidate,
} from "../src/billing/billingDispatch";
import { createBillingDispatcher } from "../src/billing/dispatcher";
import {
  type BillingVerifierDependencies,
  createBillingEventProcessor,
  reverify,
} from "../src/billing/processor";
import { startBillingReconciliation } from "../src/billing/reconciliation";

function testLogger() {
  const collector = new LogCollector();
  return {
    collector,
    logger: createJsonLogger("worker", "test", "debug", collector.sink),
  };
}

class FakeDispatch implements BillingDispatchPort {
  claimed: ClaimedBillingEvent[] = [];
  recorded: Array<[string, number, string]> = [];
  released: Array<[string, number, string]> = [];
  failed: Array<[number, string]> = [];
  payloads = new Map<number, BillingEventPayload>();
  finishOutcomeByEvent = new Map<number, BillingFinishOutcome>();
  reconcileOutcomes: Array<[string, Record<string, unknown>]> = [];
  scan: ReconciliationCandidate[] = [];
  recordResult = true;
  releaseResult = true;

  async claim() {
    return this.claimed;
  }
  async recordDispatched(workerId: string, eventId: number, jobId: string) {
    this.recorded.push([workerId, eventId, jobId]);
    return this.recordResult;
  }
  async releaseDispatch(workerId: string, eventId: number, errorCode: string) {
    this.released.push([workerId, eventId, errorCode]);
    return this.releaseResult;
  }
  async failDispatch(eventId: number, errorCode: string) {
    this.failed.push([eventId, errorCode]);
    return true;
  }
  async eventPayload(eventId: number) {
    return this.payloads.get(eventId) ?? null;
  }
  async finishEvent(eventId: number, _body: Record<string, unknown>) {
    return this.finishOutcomeByEvent.get(eventId) ?? "completed";
  }
  async reconcileTransaction(
    transactionId: string,
    body: Record<string, unknown>,
  ) {
    this.reconcileOutcomes.push([transactionId, body]);
    return "updated";
  }
  async reconciliationScan() {
    return this.scan;
  }
}

class FakeAppleVerifier implements AppleTransactionVerifier {
  notification: VerifiedAppleNotification | null = null;
  status: VerifiedAppleTransaction | null = null;
  statusError: Error | null = null;
  verifyNotificationCalls = 0;

  async verifyTransaction(): Promise<VerifiedAppleTransaction> {
    throw new Error("not used");
  }
  async verifyNotification(): Promise<VerifiedAppleNotification> {
    this.verifyNotificationCalls += 1;
    if (!this.notification) throw new Error("no fake notification");
    return this.notification;
  }
  async getSubscriptionStatus() {
    if (this.statusError) throw this.statusError;
    return this.status;
  }
}

class FakeGoogleVerifier implements GooglePurchaseVerifier {
  purchase: VerifiedGooglePurchase | null = null;
  verifyCalls = 0;
  ackCalls = 0;
  ackError: Error | null = null;

  async verifySubscription(packageName: string, purchaseToken: string) {
    this.verifyCalls += 1;
    if (!this.purchase) throw new Error("no fake purchase");
    return { ...this.purchase, packageName, purchaseToken };
  }
  async acknowledgeSubscription() {
    this.ackCalls += 1;
    if (this.ackError) throw this.ackError;
  }
  async verifyPubSubToken() {
    return true;
  }
}

function verifiedApple(
  overrides: Partial<VerifiedAppleTransaction> = {},
): VerifiedAppleTransaction {
  return {
    bundleId: "com.studafy.app",
    environment: "Production",
    originalTransactionId: "apple-orig-1",
    transactionId: "apple-txn-1",
    productId: "studafy_student_notebook_monthly",
    purchaseDate: Date.now() - 1000,
    expiresDate: Date.now() + 86400000,
    revocationReason: null,
    ...overrides,
  };
}

function verifiedGoogle(
  overrides: Partial<VerifiedGooglePurchase> = {},
): VerifiedGooglePurchase {
  return {
    packageName: "com.studafy.app",
    productId: "studafy_student_notebook_monthly",
    purchaseToken: "gpa.token-1",
    originalTransactionId: "gpa.orig-1",
    transactionId: "gpa.token-1",
    subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
    startTime: new Date(Date.now() - 3600000).toISOString(),
    expiryTime: new Date(Date.now() + 86400000).toISOString(),
    acknowledgementState: "0",
    ...overrides,
  };
}

function appleEnv(
  apple: FakeAppleVerifier,
  overrides: Partial<BillingVerifierDependencies["apple"]> = {},
) {
  return {
    verifier: apple,
    bundleId: "com.studafy.app",
    platformEnvironment: "Production" as const,
    ...overrides,
  };
}

function googleEnv(
  google: FakeGoogleVerifier,
  overrides: Partial<BillingVerifierDependencies["google"]> = {},
) {
  return {
    verifier: google,
    packageName: "com.studafy.app",
    ...overrides,
  };
}

function job(
  id: string,
  data: unknown,
  attemptsMade = 0,
  attempts = 8,
): Job {
  return {
    id,
    data,
    attemptsMade,
    opts: { attempts } as JobsOptions,
  } as Job;
}

const googleRtDn = JSON.stringify({
  subscriptionNotification: {
    purchaseToken: "gpa.token-1",
    notificationType: 4,
  },
});

describe("PAY-071 billing job ids", () => {
  test("deterministic ids round-trip an event id", () => {
    expect(billingEventJobId(42)).toBe("billing-event-42");
    expect(billingEventIdFromJobId("billing-event-42")).toBe(42);
  });
  test("garbage ids are rejected, never parsed", () => {
    expect(billingEventIdFromJobId("")).toBeNull();
    expect(billingEventIdFromJobId("billing-event-")).toBeNull();
    expect(billingEventIdFromJobId("billing-event-abc")).toBeNull();
    expect(billingEventIdFromJobId("billing-event-0")).toBeNull();
    expect(billingEventIdFromJobId("outbox-1")).toBeNull();
  });
});

describe("PAY-071 billing-events processor", () => {
  test("a Google RTDN is re-verified and finishes with the normalized body", async () => {
    const dispatch = new FakeDispatch();
    const apple = new FakeAppleVerifier();
    const google = new FakeGoogleVerifier();
    google.purchase = verifiedGoogle();
    const process = createBillingEventProcessor(
      dispatch,
      {
        environment: "production",
        apple: appleEnv(apple),
        google: googleEnv(google),
      },
      testLogger().logger,
    );
    dispatch.payloads.set(7, {
      platform: "play_store",
      environment: "production",
      rawPayload: googleRtDn,
    });
    let finished: Record<string, unknown> | null = null;
    const original = dispatch.finishEvent.bind(dispatch);
    dispatch.finishEvent = async (eventId, body) => {
      finished = body;
      return original(eventId, body);
    };

    const result = await process(job("billing-event-7", {
      platform: "play_store",
      environment: "production",
      transactionId: "7",
    }));

    expect(result).toEqual({ ok: true });
    expect(google.verifyCalls).toBe(1);
    expect(finished).toMatchObject({
      platform: "play_store",
      environment: "production",
      originalTransactionId: "gpa.orig-1",
      state: "active",
    });
  });

  test("a Google test notification is a noop, not a ledger write", async () => {
    const dispatch = new FakeDispatch();
    const google = new FakeGoogleVerifier();
    const process = createBillingEventProcessor(
      dispatch,
      { environment: "production", apple: null, google: googleEnv(google) },
      testLogger().logger,
    );
    dispatch.payloads.set(3, {
      platform: "play_store",
      environment: "production",
      rawPayload: JSON.stringify({ testNotification: { version: "1.0" } }),
    });
    let finished: Record<string, unknown> | null = null;
    const original = dispatch.finishEvent.bind(dispatch);
    dispatch.finishEvent = async (eventId, body) => {
      finished = body;
      return original(eventId, body);
    };

    const result = await process(job("billing-event-3", {
      platform: "play_store",
      environment: "production",
      transactionId: "3",
    }));

    expect(result).toEqual({ ok: true });
    expect(google.verifyCalls).toBe(0);
    expect(finished).toMatchObject({ platform: "play_store", noop: true });
  });

  test("an Apple webhook with no embedded transaction is a noop", async () => {
    const apple = new FakeAppleVerifier();
    apple.notification = {
      notificationType: "EXPIRED",
      subtype: null,
      notificationUUID: "uuid-1",
      transaction: null,
    };
    const body = await reverify(
      {
        platform: "app_store",
        environment: "production",
        rawPayload: JSON.stringify({ signedPayload: "signed.payload" }),
      },
      { environment: "production", apple: appleEnv(apple), google: null },
    );
    expect(body).toEqual({
      platform: "app_store",
      environment: "production",
      noop: true,
    });
  });

  test("an Apple sandbox transaction can never finish as production", async () => {
    const apple = new FakeAppleVerifier();
    apple.notification = {
      notificationType: "SUBSCRIBED",
      subtype: null,
      notificationUUID: "uuid-2",
      transaction: verifiedApple({ environment: "Sandbox" }),
    };
    await expect(reverify(
      {
        platform: "app_store",
        environment: "production",
        rawPayload: JSON.stringify({ signedPayload: "signed.payload" }),
      },
      { environment: "production", apple: appleEnv(apple), google: null },
    )).rejects.toThrow(/trust/i);
  });

  test("an Apple REFUND notification derives refunded regardless of status", async () => {
    const apple = new FakeAppleVerifier();
    apple.notification = {
      notificationType: "REFUND",
      subtype: null,
      notificationUUID: "uuid-3",
      transaction: verifiedApple(),
    };
    apple.status = verifiedApple({ revocationReason: null });
    const body = await reverify(
      {
        platform: "app_store",
        environment: "production",
        rawPayload: JSON.stringify({ signedPayload: "signed.payload" }),
      },
      { environment: "production", apple: appleEnv(apple), google: null },
    );
    expect(body?.state).toBe("refunded");
  });

  test("an expired Google subscription is converged without acknowledgement", async () => {
    const dispatch = new FakeDispatch();
    const google = new FakeGoogleVerifier();
    google.purchase = verifiedGoogle({
      subscriptionState: "SUBSCRIPTION_STATE_EXPIRED",
      acknowledgementState: "0",
    });
    const process = createBillingEventProcessor(
      dispatch,
      { environment: "production", apple: null, google: googleEnv(google) },
      testLogger().logger,
    );
    dispatch.payloads.set(9, {
      platform: "play_store",
      environment: "production",
      rawPayload: googleRtDn,
    });
    let finished: Record<string, unknown> | null = null;
    const original = dispatch.finishEvent.bind(dispatch);
    dispatch.finishEvent = async (eventId, body) => {
      finished = body;
      return original(eventId, body);
    };

    await process(job("billing-event-9", {
      platform: "play_store",
      environment: "production",
      transactionId: "9",
    }));

    expect(google.ackCalls).toBe(0);
    expect(finished).toMatchObject({ state: "expired", acknowledged: false });
  });

  test("a live Google subscription is acknowledged before the ledger write", async () => {
    const dispatch = new FakeDispatch();
    const google = new FakeGoogleVerifier();
    google.purchase = verifiedGoogle();
    const process = createBillingEventProcessor(
      dispatch,
      { environment: "production", apple: null, google: googleEnv(google) },
      testLogger().logger,
    );
    dispatch.payloads.set(11, {
      platform: "play_store",
      environment: "production",
      rawPayload: googleRtDn,
    });
    let finished: Record<string, unknown> | null = null;
    const original = dispatch.finishEvent.bind(dispatch);
    dispatch.finishEvent = async (eventId, body) => {
      finished = body;
      return original(eventId, body);
    };

    await process(job("billing-event-11", {
      platform: "play_store",
      environment: "production",
      transactionId: "11",
    }));

    expect(google.ackCalls).toBe(1);
    expect(finished).toMatchObject({ acknowledged: true });
  });

  test("an unknown original transaction throws a retry, never a ledger write", async () => {
    const dispatch = new FakeDispatch();
    const google = new FakeGoogleVerifier();
    google.purchase = verifiedGoogle();
    dispatch.payloads.set(5, {
      platform: "play_store",
      environment: "production",
      rawPayload: googleRtDn,
    });
    dispatch.finishOutcomeByEvent.set(5, "retry");
    const { logger, collector } = testLogger();

    const process = createBillingEventProcessor(
      dispatch,
      { environment: "production", apple: null, google: googleEnv(google) },
      logger,
    );

    await expect(process(job("billing-event-5", {
      platform: "play_store",
      environment: "production",
      transactionId: "5",
    }))).rejects.toThrow("billing original transaction unknown");
    expect(collector.events()).toContain(
      "billing_job_retry_unknown_transaction",
    );
    expect(collector.events()).not.toContain("billing_job_exhausted");
  });

  test("a dead-lettered event returns quietly as terminal", async () => {
    const dispatch = new FakeDispatch();
    const google = new FakeGoogleVerifier();
    google.purchase = verifiedGoogle();
    dispatch.payloads.set(13, {
      platform: "play_store",
      environment: "production",
      rawPayload: googleRtDn,
    });
    dispatch.finishOutcomeByEvent.set(13, "terminal");
    const process = createBillingEventProcessor(
      dispatch,
      { environment: "production", apple: null, google: googleEnv(google) },
      testLogger().logger,
    );

    const result = await process(job("billing-event-13", {
      platform: "play_store",
      environment: "production",
      transactionId: "13",
    }));
    expect(result).toEqual({ ok: true, deadLetter: true });
  });

  test("a final-attempt verification failure dead-letters the event", async () => {
    const dispatch = new FakeDispatch();
    const { logger, collector } = testLogger();
    const process = createBillingEventProcessor(
      dispatch,
      {
        environment: "production",
        apple: null,
        google: googleEnv(new FakeGoogleVerifier()),
      },
      logger,
    );
    dispatch.payloads.set(17, {
      platform: "play_store",
      environment: "production",
      rawPayload: googleRtDn,
    });

    await expect(process(
      job(
        "billing-event-17",
        {
          platform: "play_store",
          environment: "production",
          transactionId: "17",
        },
        7,
        8,
      ),
    )).rejects.toThrow("PROCESSING_FAILED");
    expect(dispatch.failed).toEqual([[17, "PROCESSING_FAILED"]]);
    expect(collector.events()).toContain("billing_job_exhausted");
  });

  test("a non-final verification failure retries without dead-lettering", async () => {
    const dispatch = new FakeDispatch();
    const { logger, collector } = testLogger();
    const process = createBillingEventProcessor(
      dispatch,
      {
        environment: "production",
        apple: null,
        google: googleEnv(new FakeGoogleVerifier()),
      },
      logger,
    );
    dispatch.payloads.set(19, {
      platform: "play_store",
      environment: "production",
      rawPayload: googleRtDn,
    });

    await expect(process(job("billing-event-19", {
      platform: "play_store",
      environment: "production",
      transactionId: "19",
    }))).rejects.toThrow("no fake purchase");
    expect(dispatch.failed).toEqual([]);
    expect(collector.events()).toContain("billing_job_retry");
  });

  test("an invalid job payload is unrecoverable", async () => {
    const dispatch = new FakeDispatch();
    const process = createBillingEventProcessor(
      dispatch,
      { environment: "production", apple: null, google: null },
      testLogger().logger,
    );
    await expect(process(job("billing-event-1", { garbage: true })))
      .rejects.toThrow("billing job payload does not match the v1 contract");
    expect(dispatch.failed).toEqual([]);
  });

  test("a job id that cannot name an event is unrecoverable", async () => {
    const dispatch = new FakeDispatch();
    const process = createBillingEventProcessor(
      dispatch,
      { environment: "production", apple: null, google: null },
      testLogger().logger,
    );
    await expect(process(job("unrelated-id", {
      platform: "play_store",
      environment: "production",
      transactionId: "1",
    }))).rejects.toThrow(
      "billing job id does not match the deterministic event contract",
    );
  });

  test("a vanished processing lease throws to retry", async () => {
    const dispatch = new FakeDispatch();
    const process = createBillingEventProcessor(
      dispatch,
      { environment: "production", apple: null, google: null },
      testLogger().logger,
    );
    await expect(process(job("billing-event-1", {
      platform: "play_store",
      environment: "production",
      transactionId: "1",
    }))).rejects.toThrow("billing event claim lost");
  });
});

function fakeQueueJobs(jobsById: Map<string, FakeJob>): Queue {
  return {
    getJob: async (jobId: string) => jobsById.get(jobId) ?? null,
    add: async (
      _name: string,
      data: unknown,
      opts: { jobId?: string } = {},
    ) => {
      const id = opts.jobId ?? `auto-${jobsById.size + 1}`;
      const f = new FakeJob(id, data);
      jobsById.set(id, f);
      return f.job;
    },
  } as unknown as Queue;
}

class FakeJob {
  readonly job: Job;
  completed = false;
  failed = false;
  constructor(
    readonly id: string,
    readonly data: unknown,
  ) {
    this.job = { id, data, opts: {} } as Job;
  }
  async isCompleted() {
    return this.completed;
  }
  async isFailed() {
    return this.failed;
  }
  async remove() {
    // The fake queue map is owned by the test; removal is a no-op marker.
    this.completed = false;
    this.failed = false;
  }
}

function dispatchRow(): ClaimedBillingEvent {
  return {
    eventId: 7,
    platform: "play_store",
    environment: "production",
    rawPayload: googleRtDn,
    bullmqJobId: null,
    attempt: 1,
  };
}

describe("PAY-071 billing dispatcher", () => {
  test("a fresh row is enqueued with a deterministic id and recorded", async () => {
    const dispatch = new FakeDispatch();
    const jobsById = new Map<string, FakeJob>();
    const dispatcher = createBillingDispatcher(
      dispatch,
      fakeQueueJobs(jobsById),
      testLogger().logger,
    );
    dispatch.claimed = [dispatchRow()];

    const drained = await dispatcher.runOnce();

    expect(drained).toBe(1);
    expect(jobsById.get("billing-event-7")).toBeDefined();
    expect(jobsById.get("billing-event-7")?.data).toMatchObject({
      platform: "play_store",
      transactionId: "7",
    });
    expect(dispatch.recorded).toEqual([[
      expect.stringContaining("pay071-dispatch-"),
      7,
      "billing-event-7",
    ]]);
  });

  test("a row already carrying a completed job is re-enqueued idempotently", async () => {
    const dispatch = new FakeDispatch();
    const jobsById = new Map<string, FakeJob>();
    const f = new FakeJob("billing-event-7", {});
    f.completed = true;
    jobsById.set("billing-event-7", f);
    const queued = fakeQueueJobs(jobsById);
    const dispatcher = createBillingDispatcher(
      dispatch,
      queued,
      testLogger().logger,
    );
    dispatch.claimed = [{ ...dispatchRow(), bullmqJobId: "billing-event-7" }];

    await dispatcher.runOnce();

    // The finished job was removed and re-added for the idempotent finish.
    expect(jobsById.get("billing-event-7")?.completed).toBe(false);
    expect(dispatch.released).toEqual([]);
  });

  test("a failed recorded job dead-letters the event", async () => {
    const dispatch = new FakeDispatch();
    const jobsById = new Map<string, FakeJob>();
    const f = new FakeJob("billing-event-7", {});
    f.failed = true;
    f.job.failedReason = "billing original transaction unknown";
    jobsById.set("billing-event-7", f);
    const dispatcher = createBillingDispatcher(
      dispatch,
      fakeQueueJobs(jobsById),
      testLogger().logger,
    );
    dispatch.claimed = [{ ...dispatchRow(), bullmqJobId: "billing-event-7" }];

    await dispatcher.runOnce();

    expect(dispatch.failed).toEqual([[7, "PROCESSING_FAILED"]]);
    expect(dispatch.released).toEqual([]);
  });

  test("an enqueue failure releases the row with a bounded code", async () => {
    const dispatch = new FakeDispatch();
    const brokenQueue = {
      getJob: async () => null,
      add: async () => {
        throw new Error("Redis connection time out");
      },
    } as unknown as Queue;
    const dispatcher = createBillingDispatcher(
      dispatch,
      brokenQueue,
      testLogger().logger,
    );
    dispatch.claimed = [dispatchRow()];

    await dispatcher.runOnce();

    expect(dispatch.released).toEqual([[
      expect.stringContaining("pay071-dispatch-"),
      7,
      "REDIS_UNAVAILABLE",
    ]]);
    expect(dispatch.recorded).toEqual([]);
  });
});

describe("PAY-071 billing reconciliation", () => {
  function candidate(
    overrides: Partial<ReconciliationCandidate> = {},
  ): ReconciliationCandidate {
    return {
      transactionId: "11111111-1111-4111-8111-111111111111",
      platform: "play_store",
      environment: "production",
      storeTransactionId: "gpa.token-1",
      originalTransactionId: "gpa.orig-1",
      state: "active",
      acknowledgedAt: null,
      purchasedAt: new Date().toISOString(),
      ...overrides,
    };
  }

  test("an active Google transaction is re-verified, acked and converged", async () => {
    const dispatch = new FakeDispatch();
    const google = new FakeGoogleVerifier();
    google.purchase = verifiedGoogle();
    const sweep = startBillingReconciliation(
      dispatch,
      { environment: "production", apple: null, google: googleEnv(google) },
      testLogger().logger,
    );
    dispatch.scan = [candidate()];

    const processed = await sweep.runOnce();
    await sweep.close();

    expect(processed).toBe(1);
    expect(google.ackCalls).toBe(1);
    expect(dispatch.reconcileOutcomes).toHaveLength(1);
    expect(dispatch.reconcileOutcomes[0]![0]).toBe(candidate().transactionId);
    expect(dispatch.reconcileOutcomes[0]![1]).toMatchObject({
      platform: "play_store",
      state: "active",
      acknowledged: true,
    });
  });

  test("an expired Google transaction is never acknowledged", async () => {
    const dispatch = new FakeDispatch();
    const google = new FakeGoogleVerifier();
    google.purchase = verifiedGoogle({
      subscriptionState: "SUBSCRIPTION_STATE_EXPIRED",
    });
    const sweep = startBillingReconciliation(
      dispatch,
      { environment: "production", apple: null, google: googleEnv(google) },
      testLogger().logger,
    );
    dispatch.scan = [candidate()];

    await sweep.runOnce();
    await sweep.close();

    expect(google.ackCalls).toBe(0);
    expect(dispatch.reconcileOutcomes[0]![1]).toMatchObject({
      state: "expired",
      acknowledged: false,
    });
  });

  test("a failed Google ack still converges without acknowledgement", async () => {
    const dispatch = new FakeDispatch();
    const google = new FakeGoogleVerifier();
    google.purchase = verifiedGoogle();
    google.ackError = new Error("ack 400");
    const sweep = startBillingReconciliation(
      dispatch,
      { environment: "production", apple: null, google: googleEnv(google) },
      testLogger().logger,
    );
    dispatch.scan = [candidate()];

    await sweep.runOnce();
    await sweep.close();

    expect(dispatch.reconcileOutcomes[0]![1]).toMatchObject({
      acknowledged: false,
    });
  });

  test("an Apple candidate is re-verified against the status API", async () => {
    const dispatch = new FakeDispatch();
    const apple = new FakeAppleVerifier();
    apple.status = verifiedApple();
    const sweep = startBillingReconciliation(
      dispatch,
      { environment: "production", apple: appleEnv(apple), google: null },
      testLogger().logger,
    );
    dispatch.scan = [
      candidate({ platform: "app_store", storeTransactionId: "apple-txn-1" }),
    ];

    await sweep.runOnce();
    await sweep.close();

    expect(dispatch.reconcileOutcomes).toHaveLength(1);
    expect(dispatch.reconcileOutcomes[0]![1]).toMatchObject({
      platform: "app_store",
      state: "active",
      originalTransactionId: "apple-orig-1",
    });
  });

  test("an untrusted Apple status never converges", async () => {
    const dispatch = new FakeDispatch();
    const apple = new FakeAppleVerifier();
    apple.status = verifiedApple({ bundleId: "com.evil.app" });
    const { collector, logger } = testLogger();
    const sweep = startBillingReconciliation(
      dispatch,
      { environment: "production", apple: appleEnv(apple), google: null },
      logger,
    );
    dispatch.scan = [
      candidate({ platform: "app_store", storeTransactionId: "apple-txn-1" }),
    ];

    await sweep.runOnce();
    await sweep.close();

    expect(dispatch.reconcileOutcomes).toHaveLength(0);
    expect(collector.events()).toContain("billing_reconcile_retry");
  });

  test("school-platform transactions are ignored, never converged", async () => {
    const dispatch = new FakeDispatch();
    const sweep = startBillingReconciliation(
      dispatch,
      { environment: "production", apple: null, google: null },
      testLogger().logger,
    );
    dispatch.scan = [candidate({ platform: "school" })];

    await sweep.runOnce();
    await sweep.close();

    expect(dispatch.reconcileOutcomes).toHaveLength(0);
  });
});

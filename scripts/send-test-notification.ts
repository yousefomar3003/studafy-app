/**
 * Sends a test push notification (docs/deployment/push-notifications.md).
 *
 *   bun scripts/send-test-notification.ts --user <profile uuid> [--no-wait]
 *     Through the real pipeline: an in-app notification for that account,
 *     which the worker fans out to its registered phones through FCM. Needs
 *     DATABASE_URL (an operator connection) and a running worker with
 *     NOTIFICATION_CHANNELS_ENABLED=true and FCM configured. Waits up to 90s
 *     and reports what the worker did.
 *
 *   bun scripts/send-test-notification.ts --token <FCM registration token>
 *     Straight to Firebase, with FCM_PROJECT_ID and FCM_SERVICE_ACCOUNT_JSON:
 *     checks the server credentials without the database or the worker.
 *     Copy a token from a debug build's log, never from the database.
 *
 * Prints ids and outcomes only, never a token or an address.
 */
import { FcmPushSender } from "@studafy/infrastructure";
import postgres from "postgres";

const args = Bun.argv.slice(2);
const option = (name: string) => {
  const index = args.indexOf(name);
  return index >= 0 ? args[index + 1] : undefined;
};
const TEST_COPY = {
  title: "Test notification",
  body: "Notifications from Studafy are working on this device.",
};

const token = option("--token");
const user = option("--user");

if (token) {
  const projectId = process.env.FCM_PROJECT_ID;
  const serviceAccountJson = process.env.FCM_SERVICE_ACCOUNT_JSON;
  if (!projectId || !serviceAccountJson) {
    throw new Error(
      "FCM_PROJECT_ID and FCM_SERVICE_ACCOUNT_JSON are required.",
    );
  }
  const sender = new FcmPushSender({ projectId, serviceAccountJson });
  const sent = await sender.send({
    token,
    ...TEST_COPY,
    data: { templateKey: "system.push_test" },
  });
  console.log(
    JSON.stringify({
      event: "push_test_sent",
      messageId: sent.providerMessageId,
    }),
  );
  process.exit(0);
}

if (!user || !/^[0-9a-f-]{36}$/i.test(user)) {
  throw new Error("Pass --user <profile uuid> or --token <FCM token>.");
}
const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL is required.");

const sql = postgres(databaseUrl, { max: 1, onnotice: () => {} });
try {
  const [account] = await sql<{ devices: number; school: string | null }[]>`
    select
      (select count(*)::int from public.push_devices d
        where d.user_id = ${user} and d.revoked_at is null) as devices,
      coalesce(
        (select m.school_id from public.memberships m
          where m.user_id = ${user} and m.active order by m.created_at limit 1),
        (select s.school_id from public.students s
          where s.user_id = ${user} and s.deleted_at is null order by s.created_at limit 1)
      ) as school
  `;
  if (!account?.school) throw new Error("That account belongs to no school.");
  if (account.devices === 0) {
    throw new Error(
      "That account has no registered phone. Sign in on a build with PUSH_ENABLED=true and allow notifications.",
    );
  }

  const key = `system.push_test:${user}:${Date.now()}`;
  await sql`
    select private.notify_recipient(
      ${account.school}::uuid, ${user}::uuid, 'system.push_test', '{}'::jsonb,
      ${key}, ${key}
    )
  `;
  console.log(
    JSON.stringify({ event: "push_test_queued", devices: account.devices }),
  );
  if (args.includes("--no-wait")) process.exit(0);

  for (let waited = 0; waited < 90; waited += 3) {
    await Bun.sleep(3000);
    const [delivery] = await sql<{ state: string; error: string | null }[]>`
      select d.state::text as state, d.error_code as error
      from public.notification_deliveries d
      join public.notification_outbox o on o.id = d.outbox_id
      where o.idempotency_key = ${key} and d.channel = 'push'
      order by d.id desc limit 1
    `;
    if (
      delivery && (delivery.state === "sent" || delivery.state === "failed")
    ) {
      console.log(JSON.stringify({ event: "push_test_result", ...delivery }));
      process.exit(delivery.state === "sent" ? 0 : 1);
    }
  }
  console.log(JSON.stringify({
    event: "push_test_timeout",
    hint:
      "Is the worker running with NOTIFICATION_CHANNELS_ENABLED=true and FCM set?",
  }));
  process.exit(1);
} finally {
  await sql.end({ timeout: 5 });
}

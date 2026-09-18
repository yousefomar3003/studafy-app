/**
 * OPS-061 DLQ operator tool (see docs/security/ops061-operator-runbook.md).
 *
 * Lists the notification dead-letter rows and optionally re-drives them.
 * The redrive itself is the audited `private.api061_redrive_dlq` transition:
 * the audit row, not this script, is the durable record.
 *
 * Run order (disposable local stack only):
 *   DATABASE_URL=… bun scripts/redrive-ops061-dlq.ts           # list
 *   DATABASE_URL=… bun scripts/redrive-ops061-dlq.ts --id 42   # redrive one
 *   DATABASE_URL=… bun scripts/redrive-ops061-dlq.ts --all     # redrive all
 */
import postgres from "postgres";

const databaseUrl = process.env.DATABASE_URL;
if (!databaseUrl) throw new Error("DATABASE_URL is required.");
const parsed = new URL(databaseUrl);
if (!["127.0.0.1", "localhost"].includes(parsed.hostname)) {
  throw new Error(
    "Refusing to operate the OPS-061 DLQ outside a local database.",
  );
}

const args = process.argv.slice(2);
const mode = args.includes("--all")
  ? "all"
  : args.includes("--id")
  ? "one"
  : "list";
const targetId = mode === "one" ? Number(args[args.indexOf("--id") + 1]) : null;

const sql = postgres(databaseUrl, { max: 1 });
try {
  const rows = await sql<{ entries: Record<string, unknown>[] }[]>`
    select private.api061_list_dlq(500) as rows
  `;
  const entries = rows[0]?.rows ?? [];

  if (mode === "list" || entries.length === 0) {
    console.log(JSON.stringify({ mode, deadLetters: entries }));
    if (mode !== "list") {
      throw new Error("no dead-letter row matched the requested redrive");
    }
  } else if (mode === "one") {
    if (!Number.isFinite(targetId)) {
      throw new Error("--id requires a numeric outbox id");
    }
    const driven = await sql<{ redriven: boolean }[]>`
      select private.api061_redrive_dlq(${targetId}) as redriven
    `;
    console.log(
      JSON.stringify({
        mode,
        id: targetId,
        redriven: driven[0]?.redriven === true,
      }),
    );
  } else {
    let driven = 0;
    for (const entry of entries) {
      const id = Number(entry["outboxId"]);
      const result = await sql<{ redriven: boolean }[]>`
        select private.api061_redrive_dlq(${id}) as redriven
      `;
      if (result[0]?.redriven === true) driven += 1;
    }
    console.log(JSON.stringify({ mode: "all", redriven: driven }));
  }
} finally {
  await sql.end({ timeout: 5 });
}

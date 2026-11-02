/**
 * How well AI-suggested marks agree with a teacher's (ADR-0046).
 *
 * Runs every case in marking-eval-cases.json through the same client,
 * prompt and reply checks the worker uses (StudyAssistant.markAnswer), and
 * reports, per case and overall: whether the suggestion fell inside the
 * marks a teacher would give, how far off it was, whether it asked for
 * review, and whether an answer that tried to instruct the marker got more
 * than it earned. It calls the real provider, so it costs a few cents.
 *
 *   AI_API_KEY=… AI_BASE_URL=https://api.together.xyz AI_MODEL=… \
 *     bun scripts/ai/marking-eval.ts [--repeat N]
 *
 * Prints marks and short reasons only - never the key.
 */
import { createStudyAssistant } from "@studafy/infrastructure";
import type { MarkingStrictness } from "@studafy/domain";
import cases from "./marking-eval-cases.json";

interface Case {
  id: string;
  lang: string;
  strictness: MarkingStrictness;
  question: string;
  max: number;
  model: string;
  keyPoints: { text: string; marks?: number }[];
  acceptedMethods?: string;
  partialCredit?: string;
  answer: string;
  expect: [number, number];
  injection?: boolean;
  reviewOk?: boolean;
}

const key = process.env["AI_API_KEY"];
const baseUrl = process.env["AI_BASE_URL"];
const model = process.env["AI_MODEL"] ?? "Qwen/Qwen3.5-9B";
if (!key || !baseUrl) {
  console.error("Set AI_API_KEY and AI_BASE_URL.");
  process.exit(2);
}
const repeatArg = process.argv.indexOf("--repeat");
const repeat = repeatArg > 0 ? Number(process.argv[repeatArg + 1]) : 1;

const assistant = createStudyAssistant({ apiKey: key, baseUrl, model });

let inRange = 0;
let within1 = 0;
let scored = 0;
let reviews = 0;
let injectionLeaks = 0;
let totalError = 0;
let tokens = 0;
const rows: string[] = [];

for (const raw of cases as Case[]) {
  for (let r = 0; r < repeat; r++) {
    const { verdict, usage } = await assistant.markAnswer(
      {
        kind: "essay",
        prompt: raw.question,
        maximumScore: raw.max,
        preferredAnswer: raw.model,
        markingGuidance: null,
        keyPoints: raw.keyPoints,
        acceptedMethods: raw.acceptedMethods ?? null,
        partialCredit: raw.partialCredit ?? null,
      },
      raw.answer,
      raw.strictness,
    );
    tokens += (usage?.inputTokens ?? 0) + (usage?.outputTokens ?? 0);
    const [lo, hi] = raw.expect;
    const score = verdict.suggestedScore;
    let mark: string;
    if (score === null) {
      reviews++;
      mark = raw.reviewOk ? "review (fine)" : "review";
      // An answer worth nothing that the model would not score counts as
      // agreeing: the teacher looks at it either way.
      if (raw.reviewOk) inRange++, within1++;
    } else {
      scored++;
      const error = score < lo ? lo - score : score > hi ? score - hi : 0;
      totalError += error;
      if (error === 0) inRange++;
      if (error <= 1) within1++;
      if (raw.injection && score > hi) injectionLeaks++;
      mark = `${score}/${raw.max}`;
    }
    rows.push(
      `${raw.id.padEnd(26)} ${raw.strictness.padEnd(8)} expected ${
        lo === hi ? lo : `${lo}-${hi}`
      }/${raw.max}  got ${mark.padEnd(14)} ${
        verdict.reviewReason ? `[${verdict.reviewReason}]` : ""
      }`,
    );
  }
}

const n = (cases as Case[]).length * repeat;
console.log(rows.join("\n"));
console.log("");
console.log(`model ${model}, ${n} suggestions`);
console.log(
  `inside the teacher's range: ${inRange}/${n} (${
    Math.round(100 * inRange / n)
  }%)`,
);
console.log(`within 1 mark: ${within1}/${n}`);
console.log(
  `mean distance outside the range (scored only): ${
    scored ? (totalError / scored).toFixed(2) : "-"
  }`,
);
console.log(`asked for review instead of scoring: ${reviews}`);
console.log(`instructions in an answer obeyed: ${injectionLeaks}`);
console.log(`tokens: ${tokens}`);

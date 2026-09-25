/**
 * Turns a linked child's records into things a parent can act on.
 *
 * Pure: no database, no clock beyond what is passed in. The interesting
 * decisions here are about restraint, so they are all testable.
 *
 * Three rules hold throughout, and each is asserted by a test:
 *
 *   1. **A child is only ever compared to themselves.** A class or year-group
 *      average is other families' data, and a parent learning where their
 *      child sits against named peers is a disclosure nobody consented to.
 *      Every comparison below is this child now against this child before.
 *   2. **Nothing is predicted or diagnosed.** No "at risk", no "likely to
 *      fail", nothing about a state of mind. A signal says what the records
 *      show and how many there were; what it means is the parent's and the
 *      school's to decide.
 *   3. **Below its threshold a signal says so.** Confidence is reported, not
 *      implied, and `insufficient` is a real answer. A claim about a child
 *      drawn from two marks is worse than silence.
 */
import type {
  V1AttendanceSummary,
  V1FamilyInsightsResponse,
  V1HomeworkSummary,
  V1InsightConfidence,
  V1InsightSignal,
  V1SubjectBreakdown,
} from "@studafy/contracts";

/** One published mark. */
export interface GradeFact {
  subject: string;
  percent: number;
  at: Date;
}

/** One register entry. */
export interface AttendanceFact {
  state: "present" | "late" | "absent" | "excused";
  at: Date;
}

/** One piece of set work, and what this child did with it. */
export interface HomeworkFact {
  assignmentId: string;
  title: string;
  dueAt: Date;
  submittedAt: Date | null;
}

export interface InsightFacts {
  grades: GradeFact[];
  attendance: AttendanceFact[];
  homework: HomeworkFact[];
}

// Sample sizes below which nothing is asserted. Deliberately not tunable per
// deployment: a threshold that can be lowered to make the product look busier
// is a threshold that will be.
const MIN_SUBJECT_GRADES = 3;
const MIN_TREND_WINDOW = 3;
const MIN_HOMEWORK = 5;
const MIN_WEEKDAY_ABSENCES = 3;
/** A subject has to sit this far below the child's own average to be named. */
const SUBJECT_FOCUS_GAP = 8;
/** Points of movement between two windows before it counts as a trend. */
const TREND_DELTA = 5;
const DUE_SOON_DAYS = 7;

const WEEKDAYS = [
  "Sunday",
  "Monday",
  "Tuesday",
  "Wednesday",
  "Thursday",
  "Friday",
  "Saturday",
];

function mean(values: number[]): number {
  return values.reduce((total, value) => total + value, 0) / values.length;
}

function round(value: number): number {
  return Math.round(value * 10) / 10;
}

/**
 * The middle mark, used for trends rather than the average.
 *
 * One catastrophic mark - a missed test scored zero, an afternoon somebody
 * was ill - drags a mean far enough to manufacture a decline that is not
 * there. Telling a parent their child is falling behind in a subject on that
 * basis is exactly the kind of claim this feature must not make, so the
 * comparison uses a statistic a single outlier cannot move.
 */
function median(values: number[]): number {
  const ordered = [...values].sort((a, b) => a - b);
  const middle = Math.floor(ordered.length / 2);
  return ordered.length % 2 === 0
    ? (ordered[middle - 1]! + ordered[middle]!) / 2
    : ordered[middle]!;
}

/** More records, more confidence - and never more than the data earns. */
function confidenceFor(count: number, minimum: number): V1InsightConfidence {
  if (count < minimum) return "insufficient";
  if (count >= minimum * 4) return "high";
  if (count >= minimum * 2) return "medium";
  return "low";
}

export function summariseAttendance(
  facts: AttendanceFact[],
): V1AttendanceSummary {
  const counts = { present: 0, late: 0, absent: 0, excused: 0 };
  for (const fact of facts) counts[fact.state] += 1;
  // Excused sessions are left out of the denominator: a school-authorised
  // absence is not the child failing to attend, and counting it as one would
  // punish an illness the school already accepted.
  const counted = counts.present + counts.late + counts.absent;
  return {
    ...counts,
    ratePercent: counted === 0
      ? null
      : round(((counts.present + counts.late) * 100) / counted),
  };
}

export function summariseHomework(facts: HomeworkFact[]): V1HomeworkSummary {
  let onTime = 0;
  let late = 0;
  let missing = 0;
  for (const fact of facts) {
    if (fact.submittedAt === null) missing += 1;
    else if (fact.submittedAt.getTime() <= fact.dueAt.getTime()) onTime += 1;
    else late += 1;
  }
  const due = facts.length;
  return {
    due,
    onTime,
    late,
    missing,
    onTimePercent: due === 0 ? null : round((onTime * 100) / due),
  };
}

export function summariseSubjects(grades: GradeFact[]): V1SubjectBreakdown[] {
  const bySubject = new Map<string, number[]>();
  for (const grade of grades) {
    const bucket = bySubject.get(grade.subject) ?? [];
    bucket.push(grade.percent);
    bySubject.set(grade.subject, bucket);
  }
  return [...bySubject.entries()]
    .map(([subject, values]) => ({
      subject,
      averagePercent: round(mean(values)),
      gradedCount: values.length,
    }))
    .sort((a, b) => a.averagePercent - b.averagePercent);
}

/** Splits a subject's marks into "before" and "recently", oldest first. */
function windows(values: GradeFact[]): { before: number[]; recent: number[] } {
  const ordered = [...values].sort((a, b) => a.at.getTime() - b.at.getTime());
  const half = Math.floor(ordered.length / 2);
  return {
    before: ordered.slice(0, half).map((g) => g.percent),
    recent: ordered.slice(half).map((g) => g.percent),
  };
}

function subjectFocus(
  grades: GradeFact[],
  subjects: V1SubjectBreakdown[],
): V1InsightSignal | null {
  if (grades.length < MIN_SUBJECT_GRADES) return null;
  const overall = mean(grades.map((g) => g.percent));
  // Already sorted weakest first, but only a subject with its own evidence
  // behind it may be named.
  const weakest = subjects.find((s) => s.gradedCount >= MIN_SUBJECT_GRADES);
  if (!weakest) return null;
  const gap = overall - weakest.averagePercent;
  if (gap < SUBJECT_FOCUS_GAP) return null;
  return {
    kind: "subject_focus",
    subject: weakest.subject,
    confidence: confidenceFor(weakest.gradedCount, MIN_SUBJECT_GRADES),
    evidence: [
      {
        label: `${weakest.subject} average`,
        value: `${weakest.averagePercent}%`,
        recordCount: weakest.gradedCount,
      },
      {
        // Their own average across everything, never anyone else's.
        label: "Their average across all subjects",
        value: `${round(overall)}%`,
        recordCount: grades.length,
      },
    ],
  };
}

function gradeTrends(grades: GradeFact[]): V1InsightSignal[] {
  const bySubject = new Map<string, GradeFact[]>();
  for (const grade of grades) {
    const bucket = bySubject.get(grade.subject) ?? [];
    bucket.push(grade);
    bySubject.set(grade.subject, bucket);
  }
  const signals: V1InsightSignal[] = [];
  for (const [subject, values] of bySubject) {
    const { before, recent } = windows(values);
    if (before.length < MIN_TREND_WINDOW || recent.length < MIN_TREND_WINDOW) {
      continue;
    }
    const delta = median(recent) - median(before);
    if (Math.abs(delta) < TREND_DELTA) continue;
    signals.push({
      kind: delta > 0 ? "grade_trend_up" : "grade_trend_down",
      subject,
      confidence: confidenceFor(values.length, MIN_TREND_WINDOW * 2),
      evidence: [
        {
          label: "Typical recent mark",
          value: `${round(median(recent))}%`,
          recordCount: recent.length,
        },
        {
          label: "Typical earlier mark",
          value: `${round(median(before))}%`,
          recordCount: before.length,
        },
        {
          label: "Change",
          value: `${delta > 0 ? "+" : ""}${round(delta)} points`,
          recordCount: values.length,
        },
      ],
    });
  }
  return signals;
}

function homeworkSignal(
  summary: V1HomeworkSummary,
): V1InsightSignal | null {
  if (summary.due < MIN_HOMEWORK || summary.onTimePercent === null) return null;
  return {
    kind: "homework_reliability",
    subject: null,
    confidence: confidenceFor(summary.due, MIN_HOMEWORK),
    evidence: [
      {
        label: "Handed in on time",
        value: `${summary.onTimePercent}%`,
        recordCount: summary.due,
      },
      { label: "Late", value: `${summary.late}`, recordCount: summary.late },
      {
        label: "Not handed in",
        value: `${summary.missing}`,
        recordCount: summary.missing,
      },
    ],
  };
}

function attendancePattern(facts: AttendanceFact[]): V1InsightSignal | null {
  const absences = facts.filter((f) => f.state === "absent");
  if (absences.length < MIN_WEEKDAY_ABSENCES) return null;
  const byWeekday = new Map<number, number>();
  for (const absence of absences) {
    const day = absence.at.getUTCDay();
    byWeekday.set(day, (byWeekday.get(day) ?? 0) + 1);
  }
  const [day, count] = [...byWeekday.entries()].sort((a, b) => b[1] - a[1])[0]!;
  // Only worth saying when one day carries most of them; an even spread is
  // just absence, and calling it a pattern would be reading tea leaves.
  if (count < MIN_WEEKDAY_ABSENCES || count * 2 <= absences.length) return null;
  return {
    kind: "attendance_pattern",
    subject: null,
    confidence: confidenceFor(count, MIN_WEEKDAY_ABSENCES),
    evidence: [
      {
        label: `Absences on a ${WEEKDAYS[day]}`,
        value: `${count}`,
        recordCount: count,
      },
      {
        label: "Absences in total",
        value: `${absences.length}`,
        recordCount: absences.length,
      },
    ],
  };
}

function dueSoon(facts: HomeworkFact[], now: Date): V1InsightSignal | null {
  const horizon = new Date(now.getTime() + DUE_SOON_DAYS * 86_400_000);
  const pending = facts.filter((f) =>
    f.submittedAt === null && f.dueAt > now && f.dueAt <= horizon
  );
  if (pending.length === 0) return null;
  return {
    kind: "due_soon_unstarted",
    subject: null,
    // A count of things with due dates is a fact, not an inference.
    confidence: "high",
    evidence: [
      {
        label: `Due in the next ${DUE_SOON_DAYS} days, not handed in`,
        value: `${pending.length}`,
        recordCount: pending.length,
      },
    ],
  };
}

/**
 * Everything worth a parent's attention, most actionable first.
 *
 * Ordering is deliberate: what is due this week can still be acted on today,
 * whereas a term's grade trend is context. A parent who reads only the first
 * card should get the one that is still changeable.
 */
export function deriveSignals(
  facts: InsightFacts,
  now: Date,
): V1InsightSignal[] {
  const subjects = summariseSubjects(facts.grades);
  const homework = summariseHomework(facts.homework);
  const ordered: (V1InsightSignal | null)[] = [
    dueSoon(facts.homework, now),
    ...gradeTrends(facts.grades).filter((s) => s.kind === "grade_trend_down"),
    subjectFocus(facts.grades, subjects),
    homeworkSignal(homework),
    attendancePattern(facts.attendance),
    ...gradeTrends(facts.grades).filter((s) => s.kind === "grade_trend_up"),
  ];
  return ordered.filter((signal): signal is V1InsightSignal => signal !== null)
    .slice(0, 10);
}

export function buildInsights(
  base: Omit<
    V1FamilyInsightsResponse,
    | "gradedCount"
    | "averagePercent"
    | "subjects"
    | "attendance"
    | "homework"
    | "signals"
  >,
  facts: InsightFacts,
  now: Date,
): V1FamilyInsightsResponse {
  const subjects = summariseSubjects(facts.grades);
  return {
    ...base,
    gradedCount: facts.grades.length,
    averagePercent: facts.grades.length === 0
      ? null
      : round(mean(facts.grades.map((g) => g.percent))),
    subjects,
    attendance: summariseAttendance(facts.attendance),
    homework: summariseHomework(facts.homework),
    signals: deriveSignals(facts, now),
  };
}

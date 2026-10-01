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
  V1ClassInsight,
  V1ClassTrend,
  V1FamilyInsightsResponse,
  V1HomeworkSummary,
  V1InsightConfidence,
  V1InsightPeriod,
  V1InsightSignal,
  V1InsightTimelinePoint,
  V1MissingWork,
  V1RecentMark,
  V1SubjectBreakdown,
} from "@studafy/contracts";

/**
 * One published mark. `subject` is the class it was set in (a class is a
 * subject here). `percent` is null for a test the child missed: a missed
 * test is reported as missed, never averaged in as a zero.
 */
export interface GradeFact {
  subject: string;
  percent: number | null;
  at: Date;
  classroomId?: string;
  title?: string;
  paper?: boolean;
}

/**
 * Register entries in one state: either one entry (`at`), or `count` of them
 * on one school-local `weekday` (0 = Sunday), as SQL counts them.
 */
export interface AttendanceFact {
  state: "present" | "late" | "absent" | "excused";
  at?: Date;
  weekday?: number;
  count?: number;
  classroomId?: string;
  className?: string;
}

/** One piece of set work, and what this child did with it. */
export interface HomeworkFact {
  assignmentId: string;
  title: string;
  dueAt: Date;
  submittedAt: Date | null;
  classroomId?: string;
  className?: string;
}

/** A class the child is in now, marked or not. */
export interface ClassFact {
  classroomId: string;
  className: string;
}

export interface InsightFacts {
  grades: GradeFact[];
  attendance: AttendanceFact[];
  homework: HomeworkFact[];
  classes?: ClassFact[];
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
/** Sessions needed before an attendance rate is worth a card of its own. */
const MIN_ATTENDANCE_SESSIONS = 10;
/** Below this rate (present or late over counted sessions) it is named. */
const ATTENDANCE_CONCERN_PERCENT = 90;

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

function countOf(fact: AttendanceFact): number {
  return fact.count ?? 1;
}

function weekdayOf(fact: AttendanceFact): number | null {
  if (fact.weekday !== undefined) return fact.weekday;
  return fact.at === undefined ? null : fact.at.getUTCDay();
}

/** Marks that were actually marked: a missed test has no percent. */
function scored(grades: GradeFact[]): (GradeFact & { percent: number })[] {
  return grades.filter((g): g is GradeFact & { percent: number } =>
    g.percent !== null
  );
}

export function summariseAttendance(
  facts: AttendanceFact[],
): V1AttendanceSummary {
  const counts = { present: 0, late: 0, absent: 0, excused: 0 };
  for (const fact of facts) counts[fact.state] += countOf(fact);
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
  for (const grade of scored(grades)) {
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
  const ordered = scored(values).sort((a, b) =>
    a.at.getTime() - b.at.getTime()
  );
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
  const marked = scored(grades);
  if (marked.length < MIN_SUBJECT_GRADES) return null;
  const overall = mean(marked.map((g) => g.percent));
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
        code: "class_average",
      },
      {
        // Their own average across everything, never anyone else's.
        label: "Their average across all subjects",
        value: `${round(overall)}%`,
        recordCount: marked.length,
        code: "overall_average",
      },
    ],
  };
}

/** The class the child does best in, against their own average. */
function strength(
  grades: GradeFact[],
  subjects: V1SubjectBreakdown[],
): V1InsightSignal | null {
  const marked = scored(grades);
  if (marked.length < MIN_SUBJECT_GRADES) return null;
  const overall = mean(marked.map((g) => g.percent));
  const strongest = [...subjects].reverse().find((s) =>
    s.gradedCount >= MIN_SUBJECT_GRADES
  );
  if (!strongest || strongest.averagePercent - overall < SUBJECT_FOCUS_GAP) {
    return null;
  }
  return {
    kind: "strength",
    subject: strongest.subject,
    confidence: confidenceFor(strongest.gradedCount, MIN_SUBJECT_GRADES),
    evidence: [
      {
        label: `${strongest.subject} average`,
        value: `${strongest.averagePercent}%`,
        recordCount: strongest.gradedCount,
        code: "class_average",
      },
      {
        label: "Their average across all subjects",
        value: `${round(overall)}%`,
        recordCount: marked.length,
        code: "overall_average",
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
          code: "recent_typical",
        },
        {
          label: "Typical earlier mark",
          value: `${round(median(before))}%`,
          recordCount: before.length,
          code: "earlier_typical",
        },
        {
          label: "Change",
          value: `${delta > 0 ? "+" : ""}${round(delta)}`,
          recordCount: before.length + recent.length,
          code: "change",
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
        code: "on_time",
      },
      {
        label: "Late",
        value: `${summary.late}`,
        recordCount: summary.late,
        code: "late",
      },
      {
        label: "Not handed in",
        value: `${summary.missing}`,
        recordCount: summary.missing,
        code: "not_handed_in",
      },
    ],
  };
}

function attendancePattern(facts: AttendanceFact[]): V1InsightSignal | null {
  let total = 0;
  const byWeekday = new Map<number, number>();
  for (const fact of facts) {
    if (fact.state !== "absent") continue;
    total += countOf(fact);
    const day = weekdayOf(fact);
    if (day === null) continue;
    byWeekday.set(day, (byWeekday.get(day) ?? 0) + countOf(fact));
  }
  if (total < MIN_WEEKDAY_ABSENCES || byWeekday.size === 0) return null;
  const [day, count] = [...byWeekday.entries()].sort((a, b) =>
    b[1] - a[1] || a[0] - b[0]
  )[0]!;
  // Only worth saying when one day carries most of them; an even spread is
  // just absence, and calling it a pattern would be reading tea leaves.
  if (count < MIN_WEEKDAY_ABSENCES || count * 2 <= total) return null;
  return {
    kind: "attendance_pattern",
    subject: null,
    confidence: confidenceFor(count, MIN_WEEKDAY_ABSENCES),
    evidence: [
      {
        label: `Absences on a ${WEEKDAYS[day]}`,
        value: `${count}`,
        recordCount: count,
        code: "weekday_absences",
        weekday: day,
      },
      {
        label: "Absences in total",
        value: `${total}`,
        recordCount: total,
        code: "absences_total",
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
        code: "due_soon",
      },
    ],
  };
}

/** Work whose deadline has passed and that never came in. A count of
 * records, so it is stated as a fact at any size. */
function missingWorkSignal(
  facts: HomeworkFact[],
  now: Date,
): V1InsightSignal | null {
  const missing = pastDue(facts, now);
  if (missing.length === 0) return null;
  return {
    kind: "missing_work",
    subject: singleClass(missing.map((m) => m.className ?? null)),
    confidence: "high",
    evidence: [
      {
        label: "Past the deadline, not handed in",
        value: `${missing.length}`,
        recordCount: missing.length,
        code: "past_due",
      },
    ],
  };
}

/** Tests the teacher recorded the child as missing. Also a plain count. */
function missedAssessmentsSignal(grades: GradeFact[]): V1InsightSignal | null {
  const missed = grades.filter((g) => g.percent === null);
  if (missed.length === 0) return null;
  return {
    kind: "missed_assessments",
    subject: singleClass(missed.map((g) => g.subject)),
    confidence: "high",
    evidence: [
      {
        label: "Tests missed",
        value: `${missed.length}`,
        recordCount: missed.length,
        code: "missed_assessments",
      },
    ],
  };
}

function attendanceLow(facts: AttendanceFact[]): V1InsightSignal | null {
  const summary = summariseAttendance(facts);
  const counted = summary.present + summary.late + summary.absent;
  if (
    counted < MIN_ATTENDANCE_SESSIONS || summary.ratePercent === null ||
    summary.ratePercent >= ATTENDANCE_CONCERN_PERCENT
  ) {
    return null;
  }
  return {
    kind: "attendance_low",
    subject: null,
    confidence: confidenceFor(counted, MIN_ATTENDANCE_SESSIONS),
    evidence: [
      {
        label: "Attended",
        value: `${summary.ratePercent}%`,
        recordCount: counted,
        code: "attendance_rate",
      },
      {
        label: "Absences in total",
        value: `${summary.absent}`,
        recordCount: summary.absent,
        code: "absences_total",
      },
    ],
  };
}

/** The one class all of these are in, or null when they span several. */
function singleClass(names: (string | null)[]): string | null {
  const distinct = new Set(names);
  if (distinct.size !== 1) return null;
  return [...distinct][0] ?? null;
}

function pastDue(facts: HomeworkFact[], now: Date): HomeworkFact[] {
  return facts.filter((f) => f.submittedAt === null && f.dueAt <= now);
}

/** Only work whose deadline has passed can be on time, late or missing. */
function dueBy(facts: HomeworkFact[], now: Date): HomeworkFact[] {
  return facts.filter((f) => f.dueAt <= now || f.submittedAt !== null);
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
  const homework = summariseHomework(dueBy(facts.homework, now));
  const trends = gradeTrends(facts.grades);
  const ordered: (V1InsightSignal | null)[] = [
    dueSoon(facts.homework, now),
    missingWorkSignal(facts.homework, now),
    missedAssessmentsSignal(facts.grades),
    ...trends.filter((s) => s.kind === "grade_trend_down"),
    subjectFocus(facts.grades, subjects),
    attendanceLow(facts.attendance),
    homeworkSignal(homework),
    attendancePattern(facts.attendance),
    strength(facts.grades, subjects),
    ...trends.filter((s) => s.kind === "grade_trend_up"),
  ];
  return ordered.filter((signal): signal is V1InsightSignal => signal !== null)
    .slice(0, 10);
}

function trendOf(values: GradeFact[]): {
  trend: V1ClassTrend;
  points: number | null;
} {
  const { before, recent } = windows(values);
  if (before.length < MIN_TREND_WINDOW || recent.length < MIN_TREND_WINDOW) {
    return { trend: "insufficient", points: null };
  }
  const delta = round(median(recent) - median(before));
  if (Math.abs(delta) < TREND_DELTA) return { trend: "steady", points: delta };
  return { trend: delta > 0 ? "up" : "down", points: delta };
}

/**
 * One line per class: marks, trend, missed tests, attendance and homework,
 * weakest first. `standing` names the child's strongest and weakest class
 * against their OTHER classes, and only between classes that each have
 * enough marks to be judged.
 */
export function summariseClasses(
  facts: InsightFacts,
  now: Date,
): V1ClassInsight[] {
  interface Bucket {
    classroomId: string;
    className: string;
    grades: GradeFact[];
    attendance: AttendanceFact[];
    homework: HomeworkFact[];
  }
  const buckets = new Map<string, Bucket>();
  const bucket = (id: string | undefined, name: string | undefined) => {
    if (!id || !name) return null;
    let found = buckets.get(id);
    if (!found) {
      found = {
        classroomId: id,
        className: name,
        grades: [],
        attendance: [],
        homework: [],
      };
      buckets.set(id, found);
    }
    return found;
  };
  for (const c of facts.classes ?? []) bucket(c.classroomId, c.className);
  for (const g of facts.grades) {
    bucket(g.classroomId, g.subject)?.grades.push(g);
  }
  for (const a of facts.attendance) {
    bucket(a.classroomId, a.className)?.attendance.push(a);
  }
  for (const h of facts.homework) {
    bucket(h.classroomId, h.className)?.homework.push(h);
  }

  const lines = [...buckets.values()].map((b): V1ClassInsight => {
    const marked = scored(b.grades).sort((x, y) =>
      x.at.getTime() - y.at.getTime()
    );
    const attendance = summariseAttendance(b.attendance);
    const homework = summariseHomework(dueBy(b.homework, now));
    const { trend, points } = trendOf(b.grades);
    return {
      classroomId: b.classroomId,
      className: b.className,
      averagePercent: marked.length === 0
        ? null
        : round(mean(marked.map((g) => g.percent))),
      gradedCount: marked.length,
      latestPercent: marked.length === 0
        ? null
        : round(marked[marked.length - 1]!.percent),
      trend,
      trendPoints: points,
      missedAssessments: b.grades.filter((g) => g.percent === null).length,
      attendanceRatePercent: attendance.ratePercent,
      absences: attendance.absent,
      homeworkDue: homework.due,
      homeworkMissing: homework.missing,
      homeworkLate: homework.late,
      homeworkOnTimePercent: homework.onTimePercent,
      standing: null,
    };
  });

  const judged = lines.filter((l) =>
    l.averagePercent !== null && l.gradedCount >= MIN_SUBJECT_GRADES
  ).sort((a, b) => a.averagePercent! - b.averagePercent!);
  if (judged.length >= 2) {
    const weakest = judged[0]!;
    const strongest = judged[judged.length - 1]!;
    if (strongest.averagePercent! > weakest.averagePercent!) {
      weakest.standing = "weakest";
      strongest.standing = "strongest";
    }
  }

  // Weakest first; classes with nothing marked yet go last, by name.
  return lines.sort((a, b) => {
    if (a.averagePercent === null || b.averagePercent === null) {
      if (a.averagePercent === b.averagePercent) {
        return a.className.localeCompare(b.className);
      }
      return a.averagePercent === null ? 1 : -1;
    }
    return a.averagePercent - b.averagePercent ||
      a.className.localeCompare(b.className);
  }).slice(0, 50);
}

/**
 * The child's average mark per week (last 30 days) or per month (longer),
 * oldest first, for the chart. A stretch with no marks is left out rather
 * than drawn as zero.
 */
export function timeline(
  grades: GradeFact[],
  period: V1InsightPeriod,
): V1InsightTimelinePoint[] {
  const buckets = new Map<number, number[]>();
  for (const grade of scored(grades)) {
    const at = grade.at;
    let start: Date;
    if (period === "last30") {
      start = new Date(Date.UTC(
        at.getUTCFullYear(),
        at.getUTCMonth(),
        at.getUTCDate() - at.getUTCDay(),
      ));
    } else {
      start = new Date(Date.UTC(at.getUTCFullYear(), at.getUTCMonth(), 1));
    }
    const key = start.getTime();
    const values = buckets.get(key) ?? [];
    values.push(grade.percent);
    buckets.set(key, values);
  }
  return [...buckets.entries()]
    .sort((a, b) => a[0] - b[0])
    .slice(-26)
    .map(([start, values]) => ({
      start: new Date(start).toISOString(),
      averagePercent: round(mean(values)),
      gradedCount: values.length,
    }));
}

export function recentMarks(grades: GradeFact[]): V1RecentMark[] {
  return [...grades]
    .sort((a, b) => b.at.getTime() - a.at.getTime())
    .slice(0, 10)
    .map((g) => ({
      title: g.title ?? g.subject,
      className: g.subject,
      percent: g.percent === null ? null : round(g.percent),
      mark: g.percent === null ? "absent" : "scored",
      paper: g.paper ?? false,
      at: g.at.toISOString(),
    }));
}

export function missingWork(
  facts: HomeworkFact[],
  now: Date,
): V1MissingWork[] {
  return pastDue(facts, now)
    .sort((a, b) => b.dueAt.getTime() - a.dueAt.getTime())
    .slice(0, 20)
    .map((f) => ({
      assignmentId: f.assignmentId,
      title: f.title,
      className: f.className ?? null,
      dueAt: f.dueAt.toISOString(),
    }));
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
    | "averageChange"
    | "missedAssessments"
    | "classes"
    | "timeline"
    | "recentMarks"
    | "missingWork"
  >,
  facts: InsightFacts,
  now: Date,
): V1FamilyInsightsResponse {
  const subjects = summariseSubjects(facts.grades);
  const marked = scored(facts.grades);
  return {
    ...base,
    gradedCount: marked.length,
    averagePercent: marked.length === 0
      ? null
      : round(mean(marked.map((g) => g.percent))),
    subjects,
    attendance: summariseAttendance(facts.attendance),
    // Work not yet due is neither on time nor missing.
    homework: summariseHomework(dueBy(facts.homework, now)),
    signals: deriveSignals(facts, now),
    averageChange: trendOf(facts.grades).points,
    missedAssessments: facts.grades.length - marked.length,
    classes: summariseClasses(facts, now),
    timeline: timeline(facts.grades, base.period),
    recentMarks: recentMarks(facts.grades),
    missingWork: missingWork(facts.homework, now),
  };
}

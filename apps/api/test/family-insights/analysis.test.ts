/**
 * Family+ says things about somebody's child, for money. What it refuses to
 * say matters as much as what it reports, so the thresholds and the three
 * standing rules are pinned here rather than left to review.
 */
import { describe, expect, test } from "bun:test";
import {
  type AttendanceFact,
  deriveSignals,
  type GradeFact,
  type HomeworkFact,
  summariseAttendance,
  summariseHomework,
  summariseSubjects,
} from "../../src/family-insights/analysis";

const NOW = new Date("2026-09-24T09:00:00.000Z");

function day(offset: number): Date {
  return new Date(NOW.getTime() + offset * 86_400_000);
}

function grades(
  subject: string,
  percents: number[],
  startOffset = -60,
): GradeFact[] {
  return percents.map((percent, index) => ({
    subject,
    percent,
    at: day(startOffset + index * 3),
  }));
}

describe("summaries", () => {
  test("an authorised absence is not counted against attendance", () => {
    const facts: AttendanceFact[] = [
      { state: "present", at: day(-5) },
      { state: "present", at: day(-4) },
      { state: "excused", at: day(-3) },
      { state: "absent", at: day(-2) },
    ];

    // 2 of 3 counted sessions, not 2 of 4: the school authorised the third,
    // and counting it would punish an illness it already accepted.
    expect(summariseAttendance(facts).ratePercent).toBe(66.7);
    expect(summariseAttendance(facts).excused).toBe(1);
  });

  test("attendance with nothing recorded reports null, not zero", () => {
    // Zero would read as "never attends" on a parent's screen.
    expect(summariseAttendance([]).ratePercent).toBeNull();
  });

  test("late work is neither on time nor missing", () => {
    const facts: HomeworkFact[] = [
      { assignmentId: "a", title: "A", dueAt: day(-5), submittedAt: day(-6) },
      { assignmentId: "b", title: "B", dueAt: day(-5), submittedAt: day(-4) },
      { assignmentId: "c", title: "C", dueAt: day(-5), submittedAt: null },
    ];
    const summary = summariseHomework(facts);

    expect(summary).toMatchObject({ due: 3, onTime: 1, late: 1, missing: 1 });
  });

  test("work handed in exactly on the deadline is on time", () => {
    const due = day(-2);
    expect(
      summariseHomework([
        { assignmentId: "a", title: "A", dueAt: due, submittedAt: due },
      ]).onTime,
    ).toBe(1);
  });

  test("subjects are ordered weakest first", () => {
    const subjects = summariseSubjects([
      ...grades("Maths", [40, 45, 50]),
      ...grades("Art", [90, 95, 92]),
    ]);

    expect(subjects.map((s) => s.subject)).toEqual(["Maths", "Art"]);
    expect(subjects[0]!.gradedCount).toBe(3);
  });
});

describe("the three standing rules", () => {
  test("nothing is asserted below the sample threshold", () => {
    // Two marks in one subject: a real fall, and far too little to say so.
    const signals = deriveSignals(
      { grades: grades("Maths", [80, 40]), attendance: [], homework: [] },
      NOW,
    );

    expect(signals).toEqual([]);
  });

  test("a single poor mark does not become a trend", () => {
    const signals = deriveSignals(
      {
        grades: grades("Maths", [70, 72, 71, 70, 73, 20]),
        attendance: [],
        homework: [],
      },
      NOW,
    );

    // One bad afternoon moves the recent window, but not by enough to call a
    // direction, which is the point of the threshold.
    expect(signals.filter((s) => s.kind === "grade_trend_down")).toEqual([]);
  });

  test("every comparison is the child against their own record", () => {
    const signals = deriveSignals(
      {
        grades: [
          ...grades("Maths", [40, 42, 38]),
          ...grades("Art", [90, 92, 88]),
        ],
        attendance: [],
        homework: [],
      },
      NOW,
    );
    const labels = signals.flatMap((s) => s.evidence.map((e) => e.label));

    // No class, cohort or peer wording may ever appear: that would be other
    // families' data reaching this one.
    for (const word of ["class", "peer", "cohort", "year group", "rank"]) {
      expect(labels.join(" ").toLowerCase()).not.toContain(word);
    }
    expect(labels).toContain("Their average across all subjects");
  });

  test("no signal predicts an outcome or describes a state of mind", () => {
    const signals = deriveSignals(
      {
        grades: grades("Maths", [80, 78, 75, 50, 48, 45]),
        attendance: [
          { state: "absent", at: new Date("2026-09-07T09:00:00.000Z") },
          { state: "absent", at: new Date("2026-09-14T09:00:00.000Z") },
          { state: "absent", at: new Date("2026-09-21T09:00:00.000Z") },
        ],
        homework: [],
      },
      NOW,
    );

    expect(signals.length).toBeGreaterThan(0);
    // The kinds are descriptive by construction; this pins that nobody adds a
    // predictive one without changing a test that says why they must not.
    for (const signal of signals) {
      expect(signal.kind).not.toContain("risk");
      expect(signal.kind).not.toContain("predict");
      expect(signal.kind).not.toContain("likely");
    }
  });
});

describe("signals", () => {
  test("a sustained fall is reported with both windows as evidence", () => {
    const signals = deriveSignals(
      {
        grades: grades("Maths", [80, 82, 78, 55, 52, 50]),
        attendance: [],
        homework: [],
      },
      NOW,
    );
    const fall = signals.find((s) => s.kind === "grade_trend_down");

    expect(fall?.subject).toBe("Maths");
    expect(fall?.evidence.map((e) => e.label)).toEqual([
      "Typical recent mark",
      "Typical earlier mark",
      "Change",
    ]);
    // A parent can check the claim against the marks they can see.
    expect(fall?.evidence[2]?.value).toContain("-");
  });

  test("a sustained rise is reported too", () => {
    const signals = deriveSignals(
      {
        grades: grades("Maths", [50, 52, 48, 78, 80, 82]),
        attendance: [],
        homework: [],
      },
      NOW,
    );

    expect(signals.some((s) => s.kind === "grade_trend_up")).toBe(true);
  });

  test("work due this week that is not handed in comes first", () => {
    const signals = deriveSignals(
      {
        grades: grades("Maths", [80, 82, 78, 55, 52, 50]),
        attendance: [],
        homework: [
          {
            assignmentId: "a",
            title: "Essay",
            dueAt: day(2),
            submittedAt: null,
          },
        ],
      },
      NOW,
    );

    // Still actionable today, unlike a term's trend.
    expect(signals[0]!.kind).toBe("due_soon_unstarted");
  });

  test("work already handed in is not chased", () => {
    const signals = deriveSignals(
      {
        grades: [],
        attendance: [],
        homework: [
          {
            assignmentId: "a",
            title: "Essay",
            dueAt: day(2),
            submittedAt: day(-1),
          },
        ],
      },
      NOW,
    );

    expect(signals).toEqual([]);
  });

  test("absences spread evenly are not called a pattern", () => {
    const signals = deriveSignals(
      {
        grades: [],
        attendance: [
          { state: "absent", at: new Date("2026-09-07T09:00:00.000Z") },
          { state: "absent", at: new Date("2026-09-08T09:00:00.000Z") },
          { state: "absent", at: new Date("2026-09-09T09:00:00.000Z") },
          { state: "absent", at: new Date("2026-09-10T09:00:00.000Z") },
        ],
        homework: [],
      },
      NOW,
    );

    expect(signals.filter((s) => s.kind === "attendance_pattern")).toEqual([]);
  });

  test("absences concentrated on one weekday are", () => {
    const signals = deriveSignals(
      {
        grades: [],
        attendance: [
          { state: "absent", at: new Date("2026-09-07T09:00:00.000Z") },
          { state: "absent", at: new Date("2026-09-14T09:00:00.000Z") },
          { state: "absent", at: new Date("2026-09-21T09:00:00.000Z") },
        ],
        homework: [],
      },
      NOW,
    );
    const pattern = signals.find((s) => s.kind === "attendance_pattern");

    expect(pattern?.evidence[0]?.label).toContain("Monday");
    expect(pattern?.evidence[0]?.recordCount).toBe(3);
  });

  test("confidence grows with the record count and never beyond it", () => {
    const thin = deriveSignals(
      { grades: [], attendance: [], homework: homeworkRun(5, 3) },
      NOW,
    ).find((s) => s.kind === "homework_reliability");
    const thick = deriveSignals(
      { grades: [], attendance: [], homework: homeworkRun(24, 12) },
      NOW,
    ).find((s) => s.kind === "homework_reliability");

    expect(thin?.confidence).toBe("low");
    expect(thick?.confidence).toBe("high");
  });

  test("four homework items are too few to judge reliability", () => {
    const signals = deriveSignals(
      { grades: [], attendance: [], homework: homeworkRun(4, 0) },
      NOW,
    );

    expect(signals.filter((s) => s.kind === "homework_reliability")).toEqual(
      [],
    );
  });
});

function homeworkRun(total: number, onTime: number): HomeworkFact[] {
  return Array.from({ length: total }, (_, index) => ({
    assignmentId: `a${index}`,
    title: `Task ${index}`,
    dueAt: day(-30 + index),
    submittedAt: index < onTime ? day(-31 + index) : null,
  }));
}

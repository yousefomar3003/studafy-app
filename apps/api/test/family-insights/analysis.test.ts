/**
 * Family+ says things about somebody's child, for money. What it refuses to
 * say matters as much as what it reports, so the thresholds and the three
 * standing rules are pinned here rather than left to review.
 */
import { describe, expect, test } from "bun:test";
import {
  type AttendanceFact,
  buildInsights,
  deriveSignals,
  type GradeFact,
  type HomeworkFact,
  summariseAttendance,
  summariseClasses,
  summariseHomework,
  summariseSubjects,
  timeline,
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

describe("per class", () => {
  function classGrades(
    id: string,
    name: string,
    percents: (number | null)[],
    startOffset = -60,
  ): GradeFact[] {
    return percents.map((percent, index) => ({
      subject: name,
      classroomId: id,
      title: `${name} test ${index + 1}`,
      paper: true,
      percent,
      at: day(startOffset + index * 3),
    }));
  }

  test("the weakest and strongest class are named among the child's own", () => {
    const classes = summariseClasses(
      {
        grades: [
          ...classGrades("m", "Maths", [40, 45, 50]),
          ...classGrades("a", "Art", [90, 95, 92]),
          ...classGrades("s", "Science", [70, 72, 71]),
        ],
        attendance: [],
        homework: [],
      },
      NOW,
    );

    expect(classes.map((c) => [c.className, c.standing])).toEqual([
      ["Maths", "weakest"],
      ["Science", null],
      ["Art", "strongest"],
    ]);
  });

  test("a class with too few marks is never called weakest", () => {
    const classes = summariseClasses(
      {
        grades: [
          ...classGrades("m", "Maths", [10, 12]),
          ...classGrades("a", "Art", [90, 95, 92]),
        ],
        attendance: [],
        homework: [],
      },
      NOW,
    );

    expect(classes.every((c) => c.standing === null)).toBe(true);
  });

  test("a missed test is counted as missed, not averaged in as zero", () => {
    const facts = {
      grades: classGrades("m", "Maths", [80, null, 70]),
      attendance: [],
      homework: [],
    };
    const [maths] = summariseClasses(facts, NOW);

    expect(maths!.averagePercent).toBe(75);
    expect(maths!.missedAssessments).toBe(1);
    const signals = deriveSignals(facts, NOW);
    const missed = signals.find((s) => s.kind === "missed_assessments");
    expect(missed?.subject).toBe("Maths");
    expect(missed?.evidence[0]?.value).toBe("1");
  });

  test("a class the child is in shows even with nothing marked yet", () => {
    const classes = summariseClasses(
      {
        grades: classGrades("m", "Maths", [80, 82, 84]),
        attendance: [],
        homework: [],
        classes: [
          { classroomId: "m", className: "Maths" },
          { classroomId: "h", className: "History" },
        ],
      },
      NOW,
    );

    expect(classes.map((c) => c.className)).toEqual(["Maths", "History"]);
    expect(classes[1]!.averagePercent).toBeNull();
  });

  test("each class carries its own trend, attendance and homework", () => {
    const [maths] = summariseClasses(
      {
        grades: classGrades("m", "Maths", [80, 82, 78, 55, 52, 50]),
        attendance: [
          {
            state: "present",
            count: 8,
            weekday: 1,
            classroomId: "m",
            className: "Maths",
          },
          {
            state: "absent",
            count: 2,
            weekday: 2,
            classroomId: "m",
            className: "Maths",
          },
        ],
        homework: [
          {
            assignmentId: "a",
            title: "A",
            dueAt: day(-3),
            submittedAt: null,
            classroomId: "m",
            className: "Maths",
          },
          {
            assignmentId: "b",
            title: "B",
            dueAt: day(3),
            submittedAt: null,
            classroomId: "m",
            className: "Maths",
          },
        ],
      },
      NOW,
    );

    expect(maths!.trend).toBe("down");
    expect(maths!.attendanceRatePercent).toBe(80);
    expect(maths!.absences).toBe(2);
    // The one not yet due is neither missing nor on time.
    expect(maths!.homeworkDue).toBe(1);
    expect(maths!.homeworkMissing).toBe(1);
  });
});

describe("focus", () => {
  test("work past its deadline and never handed in is named", () => {
    const signals = deriveSignals(
      {
        grades: [],
        attendance: [],
        homework: [
          {
            assignmentId: "a",
            title: "Essay",
            dueAt: day(-2),
            submittedAt: null,
            className: "English",
          },
        ],
      },
      NOW,
    );

    expect(signals[0]).toMatchObject({
      kind: "missing_work",
      subject: "English",
      confidence: "high",
    });
  });

  test("low attendance needs enough sessions before it is said", () => {
    const few = deriveSignals(
      {
        grades: [],
        attendance: [
          { state: "present", count: 3, weekday: 1 },
          { state: "absent", count: 2, weekday: 2 },
        ],
        homework: [],
      },
      NOW,
    );
    const enough = deriveSignals(
      {
        grades: [],
        attendance: [
          { state: "present", count: 16, weekday: 1 },
          { state: "absent", count: 4, weekday: 2 },
          { state: "absent", count: 1, weekday: 3 },
        ],
        homework: [],
      },
      NOW,
    );

    expect(few.some((s) => s.kind === "attendance_low")).toBe(false);
    expect(enough.find((s) => s.kind === "attendance_low")?.evidence[0])
      .toMatchObject({ code: "attendance_rate", value: "76.2%" });
  });

  test("a clear strength is named too, and last", () => {
    const signals = deriveSignals(
      {
        grades: [
          ...grades("Maths", [60, 62, 61]),
          ...grades("Art", [92, 95, 93]),
          ...grades("Science", [65, 66, 64]),
        ],
        attendance: [],
        homework: [],
      },
      NOW,
    );

    expect(signals.at(-1)).toMatchObject({ kind: "strength", subject: "Art" });
  });

  test("weekday counts from the database make a pattern the same way", () => {
    const signals = deriveSignals(
      {
        grades: [],
        attendance: [{ state: "absent", count: 3, weekday: 0 }],
        homework: [],
      },
      NOW,
    );
    const pattern = signals.find((s) => s.kind === "attendance_pattern");

    expect(pattern?.evidence[0]).toMatchObject({
      code: "weekday_absences",
      weekday: 0,
      value: "3",
    });
  });

  test("every evidence line carries a code the app can translate", () => {
    const signals = deriveSignals(
      {
        grades: [
          ...grades("Maths", [80, 82, 78, 55, 52, 50]),
          ...grades("Art", [95, 96, 94]),
          { subject: "Maths", percent: null, at: day(-1) },
        ],
        attendance: [{ state: "absent", count: 12, weekday: 1 }],
        homework: [
          ...homeworkRun(6, 2),
          { assignmentId: "z", title: "Z", dueAt: day(2), submittedAt: null },
        ],
      },
      NOW,
    );

    expect(signals.length).toBeGreaterThan(5);
    for (const signal of signals) {
      for (const line of signal.evidence) expect(line.code).toBeDefined();
    }
  });
});

describe("the whole answer", () => {
  test("marks are drawn by month, oldest first, with no empty months", () => {
    const points = timeline(
      [
        { subject: "M", percent: 60, at: new Date("2026-07-03T09:00:00Z") },
        { subject: "M", percent: 80, at: new Date("2026-07-20T09:00:00Z") },
        { subject: "M", percent: null, at: new Date("2026-08-02T09:00:00Z") },
        { subject: "M", percent: 90, at: new Date("2026-09-02T09:00:00Z") },
      ],
      "term",
    );

    expect(points).toEqual([
      { start: "2026-07-01T00:00:00.000Z", averagePercent: 70, gradedCount: 2 },
      { start: "2026-09-01T00:00:00.000Z", averagePercent: 90, gradedCount: 1 },
    ]);
  });

  test("the response names the recent marks and the missing work", () => {
    const body = buildInsights(
      {
        studentId: "5f490000-0000-4000-8000-0000000000a1",
        studentName: "Kid",
        period: "term",
        from: day(-120).toISOString(),
        to: NOW.toISOString(),
        upcoming: [],
        wellbeing: [],
      },
      {
        grades: [
          {
            subject: "Maths",
            title: "Paper exam",
            paper: true,
            percent: null,
            at: day(-1),
          },
          { subject: "Maths", title: "Quiz", percent: 80, at: day(-5) },
        ],
        attendance: [],
        homework: [
          {
            assignmentId: "5f490000-0000-4000-8000-0000000000b1",
            title: "Essay",
            dueAt: day(-2),
            submittedAt: null,
            className: "English",
          },
        ],
      },
      NOW,
    );

    expect(body.recentMarks?.[0]).toMatchObject({
      title: "Paper exam",
      mark: "absent",
      percent: null,
      paper: true,
    });
    expect(body.missedAssessments).toBe(1);
    expect(body.averagePercent).toBe(80);
    expect(body.missingWork?.[0]).toMatchObject({
      title: "Essay",
      className: "English",
    });
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

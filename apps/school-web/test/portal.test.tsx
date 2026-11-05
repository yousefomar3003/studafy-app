import { describe, expect, test } from "bun:test";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import type { ReactNode } from "react";
import { renderToString } from "react-dom/server";
import { isHiddenEmail } from "../src/portal/auth";
import { formatDay, formatNumber, ofTotal } from "../src/portal/format";
import {
  CopyContext,
  copyFor,
  errorText,
  type PortalLang,
} from "../src/portal/i18n";
import { portalAr } from "../src/portal/i18n/ar";
import { portalEn } from "../src/portal/i18n/en";
import { ClassesView } from "../src/portal/pages/Classes";
import {
  AttendanceTab,
  MarksTab,
  StudentsTab,
  WellbeingTab,
} from "../src/portal/pages/ClassPage";
import {
  DashboardView,
  Meter,
  OverviewView,
} from "../src/portal/pages/Dashboard";
import { SignIn } from "../src/portal/pages/SignIn";
import { TeachersView } from "../src/portal/pages/Teachers";
import { AnswersView, HandInsView } from "../src/portal/pages/Work";
import { StudentView, TeacherView } from "../src/portal/pages/People";
import { ReportsView } from "../src/portal/pages/Reports";
import {
  CLASS_TABS,
  hrefFor,
  parseRoute,
  type Route,
} from "../src/portal/router";
import { Loader } from "../src/portal/ui";

const ORG = "5c900000-0000-4000-8000-000000000001";
const CLASS = "5c900000-0000-4000-8000-000000000002";
const STUDENT = "5c900000-0000-4000-8000-000000000003";
const ITEM = "5c900000-0000-4000-8000-000000000004";

function render(node: ReactNode, lang: PortalLang = "en"): string {
  return renderToString(
    <CopyContext.Provider value={copyFor(lang)}>{node}</CopyContext.Provider>,
  );
}

describe("addresses", () => {
  const routes: Route[] = [
    { name: "home" },
    { name: "callback" },
    { name: "new" },
    { name: "dashboard", org: ORG },
    { name: "teachers", org: ORG },
    { name: "classes", org: ORG },
    { name: "settings", org: ORG },
    { name: "reports", org: ORG },
    { name: "student", org: ORG, student: STUDENT },
    { name: "teacher", org: ORG, teacher: STUDENT },
    ...CLASS_TABS.map((tab) =>
      ({ name: "class", org: ORG, classroom: CLASS, tab }) as Route
    ),
    { name: "handIns", org: ORG, classroom: CLASS, assignment: ITEM },
    { name: "answers", org: ORG, classroom: CLASS, test: ITEM },
  ];

  test("every page's address reads back as the same page, at the root and under /portal", () => {
    for (const base of ["", "/portal"]) {
      for (const route of routes) {
        expect(parseRoute(hrefFor(route, base) || "/")).toEqual(route);
      }
    }
  });

  test("anything else, or an id that isn't one, is not found", () => {
    for (
      const path of [
        "/o/not-an-id",
        `/o/${ORG}/nope`,
        "/admin",
        `/o/${ORG}/classes/x/marks`,
      ]
    ) {
      expect(parseRoute(path)).toEqual({ name: "notFound" });
    }
  });
});

describe("words and numbers", () => {
  function keys(value: unknown, path = ""): string[] {
    if (value && typeof value === "object") {
      return Object.entries(value).flatMap(([k, v]) => keys(v, `${path}.${k}`));
    }
    return [path];
  }

  test("English and Arabic say the same things, and nothing is empty", () => {
    expect(keys(portalAr).sort()).toEqual(keys(portalEn).sort());
    for (const copy of [portalEn, portalAr]) {
      for (const key of keys(copy)) {
        const value = key.split(".").slice(1).reduce<unknown>(
          (at, part) => (at as Record<string, unknown>)[part],
          copy,
        );
        expect(String(value).trim().length, key).toBeGreaterThan(0);
      }
    }
  });

  test("Arabic follows the app's glossary", () => {
    const text = JSON.stringify(portalAr);
    expect(text).not.toMatch(/فصل|فصول|ستدفاي/);
  });

  test("numbers use Latin digits in both languages", () => {
    expect(formatNumber(12.5, "en")).toBe("12.5");
    expect(formatNumber(12.5, "ar")).toMatch(/12[.,٫]5/);
    expect(ofTotal(3, 24, "ar")).toBe("3 / 24");
    expect(formatDay("2026-09-10", "en")).toMatch(/^10 Sep/);
    expect(formatNumber(null, "en")).toBe("—");
  });

  test("an unknown refusal gets the general words, never a raw code", () => {
    expect(errorText(portalEn, "SOMETHING_NEW")).toBe(
      portalEn.errors["generic"]!,
    );
    expect(errorText(portalAr, "TEACHER_NOT_FOUND")).toBe(
      portalAr.errors["TEACHER_NOT_FOUND"]!,
    );
  });

  test("Apple's hidden addresses are recognised", () => {
    expect(isHiddenEmail("abc123@privaterelay.appleid.com")).toBe(true);
    expect(isHiddenEmail("head@school.example")).toBe(false);
    expect(isHiddenEmail(null)).toBe(false);
  });
});

describe("screens", () => {
  test("loading, refusal and content", () => {
    const loading = render(
      <Loader value={{ state: "loading" }} onRetry={() => {}}>
        {() => "x"}
      </Loader>,
    );
    expect(loading).toContain(portalEn.loading);
    const refused = render(
      <Loader
        value={{ state: "error", code: "RATE_LIMITED" }}
        onRetry={() => {}}
      >
        {() => "x"}
      </Loader>,
      "ar",
    );
    expect(refused).toContain(portalAr.errors["RATE_LIMITED"]!);
    expect(refused).toContain(portalAr.retry);
  });

  test("sign-in says so when the site has no sign-in set up", () => {
    expect(render(<SignIn />)).toContain("available on this site yet");
  });

  test("the dashboard counts and lists waiting requests", () => {
    const empty = render(
      <DashboardView
        data={{ linkedTeachers: 0, classes: 0, students: 0, waiting: [] }}
        org={ORG}
        onChange={() => {}}
      />,
    );
    expect(empty).toContain(portalEn.dashboard.waitingEmpty);
    const full = render(
      <DashboardView
        data={{
          linkedTeachers: 2,
          classes: 5,
          students: 120,
          waiting: [{
            id: ITEM,
            teacher: {
              id: STUDENT,
              name: "Rania Haddad",
              email: "rania@example.test",
            },
            requestedAt: "2026-11-05T09:00:00Z",
          }],
        }}
        org={ORG}
        onChange={() => {}}
      />,
    );
    expect(full).toContain("Rania Haddad");
    expect(full).toContain(portalEn.dashboard.cancelRequest);
    expect(full).toContain("120");
  });

  test("overview: each class's numbers and who needs attention, with the reason", () => {
    const empty = render(
      <OverviewView data={{ classes: [], attention: [] }} org={ORG} />,
    );
    expect(empty).toContain(portalEn.overview.attentionEmpty);
    const html = render(
      <OverviewView
        data={{
          classes: [{
            classroomId: CLASS,
            name: "Grade 7 Science",
            students: 24,
            attendanceRate: 0.81,
            averageMark: 0.72,
            missing: 5,
          }],
          attention: [{
            studentId: STUDENT,
            name: "Adam Odeh",
            classroomId: CLASS,
            className: "Grade 7 Science",
            reasons: ["attendance", "missing_work"],
            attendanceRate: 0.6,
            averageMark: 0.58,
            missing: 3,
          }],
        }}
        org={ORG}
      />,
    );
    expect(html).toContain("Adam Odeh");
    expect(html).toContain(portalEn.overview.reasons.attendance);
    expect(html).toContain("60%");
    expect(html).toContain("81%");
  });

  test("a rate's bar never shows colour alone, and an unknown rate is a dash", () => {
    expect(render(<Meter value={0.42} lang="en" />)).toContain("42%");
    expect(render(<Meter value={0.42} lang="en" />)).toContain("meter-bar bad");
    expect(render(<Meter value={null} lang="en" />)).toContain("—");
  });

  test("a student's page: classes, missing work, marks and notes", () => {
    const html = render(
      <StudentView
        org={ORG}
        data={{
          student: {
            studentId: STUDENT,
            name: "Adam Odeh",
            studafyId: "SJ-0A1B2C3D4E",
            email: "adam@student.example",
            parents: [],
          },
          classes: [{
            classroomId: CLASS,
            name: "Grade 7 Science",
            teachers: ["Rania Haddad"],
            attendanceRate: 0.6,
            averageMark: 0.58,
            missing: 3,
          }],
          recentMarks: [{
            assessmentId: ITEM,
            title: "Quiz 1",
            className: "Grade 7 Science",
            score: 4,
            maximumScore: 10,
            mark: "scored",
            state: "draft",
            at: "2026-11-03T09:00:00Z",
          }],
          missingWork: [{
            assignmentId: ITEM,
            title: "Essay on rivers",
            className: "Grade 7 Science",
            dueAt: "2026-11-02T18:00:00Z",
          }],
          wellbeing: [],
        }}
      />,
    );
    for (
      const text of [
        "Adam Odeh",
        "Grade 7 Science",
        "Essay on rivers",
        "60%",
        portalEn.marks.notPublished,
        portalEn.people.noWellbeing,
      ]
    ) {
      expect(html).toContain(text);
    }
  });

  test("a teacher's page: classes, recent lessons and marking still to do", () => {
    const html = render(
      <TeacherView
        org={ORG}
        data={{
          teacher: {
            id: STUDENT,
            name: "Rania Haddad",
            email: "rania@cedar.example",
            studafyId: "4821937560",
            linkedSince: "2026-11-02T10:00:00Z",
          },
          classes: [{
            classroomId: CLASS,
            name: "Grade 7 Science",
            students: 24,
            attendanceRate: 0.81,
            averageMark: 0.72,
            missing: 5,
          }],
          recentLessons: [],
          toMark: { testAnswers: 3, handIns: 2 },
        }}
      />,
    );
    for (
      const text of [
        "Rania Haddad",
        "Grade 7 Science",
        portalEn.people.testAnswers,
        portalEn.people.noLessons,
      ]
    ) {
      expect(html).toContain(text);
    }
  });

  test("reports: weekly bars with values on hover, classes compared, marks by band", () => {
    const weeks = Array.from({ length: 12 }, (_, i) => ({
      weekStart: new Date(Date.UTC(2026, 7, 17 + i * 7)).toISOString().slice(
        0,
        10,
      ),
      attendanceRate: i === 0 ? null : 0.9,
    }));
    const html = render(
      <ReportsView
        org={ORG}
        data={{
          weeks,
          classes: [{
            classroomId: CLASS,
            name: "Grade 7 Science",
            students: 24,
            attendanceRate: 0.84,
            averageMark: 0.72,
            handInRate: 0.78,
            bands: { below50: 2, from50: 4, from70: 8, from85: 4 },
            weeks,
          }],
        }}
      />,
    );
    // Every week has a hover title; a week with no lessons says so.
    expect(html.match(/<title>/g)?.length).toBeGreaterThanOrEqual(12);
    expect(html).toContain(portalEn.reports.noData);
    expect(html).toContain("78%");
    // The legend names each band, and a table view exists.
    expect(html).toContain(portalEn.reports.bands.from85);
    expect(html).toContain(portalEn.reports.asTable);
    expect(render(<ReportsView org={ORG} data={{ weeks, classes: [] }} />))
      .toContain(portalEn.classes.empty);
  });

  test("teachers: empty, and Unlink only for a linked teacher", () => {
    expect(
      render(
        <TeachersView data={{ teachers: [] }} org={ORG} onChange={() => {}} />,
      ),
    )
      .toContain(portalEn.teachers.empty);
    const html = render(
      <TeachersView
        data={{
          teachers: [
            {
              id: "a",
              name: "Linked One",
              email: "l@x.test",
              linkId: ITEM,
              studafyId: "1234567890",
              status: "linked",
              requestedAt: "2026-11-01T09:00:00Z",
              decidedAt: "2026-11-02T09:00:00Z",
              endedAt: null,
              classes: 3,
            },
            {
              id: "b",
              name: "Waiting One",
              email: "w@x.test",
              linkId: CLASS,
              studafyId: "1234567891",
              status: "pending",
              requestedAt: "2026-11-04T09:00:00Z",
              decidedAt: null,
              endedAt: null,
              classes: 0,
            },
          ],
        }}
        org={ORG}
        onChange={() => {}}
      />,
    );
    expect(html.split(portalEn.teachers.unlink).length - 1).toBe(1);
    expect(html).toContain(portalEn.teachers.statuses.pending);
  });

  test("classes: empty, and a list of linked classes", () => {
    expect(render(<ClassesView data={{ classes: [] }} org={ORG} />)).toContain(
      portalEn.classes.empty,
    );
    const html = render(
      <ClassesView
        data={{
          classes: [{
            id: CLASS,
            name: "Grade 7 Science",
            grade: "7",
            section: "A",
            status: "active",
            timezone: "Asia/Amman",
            teachers: [{ id: "t", name: "Rania Haddad", role: "lead_teacher" }],
            students: 24,
          }],
        }}
        org={ORG}
      />,
    );
    expect(html).toContain("Grade 7 Science");
    expect(html).toContain(`/o/${ORG}/classes/${CLASS}/students`);
  });

  test("students show emails, Studafy IDs and linked parents", () => {
    const html = render(
      <StudentsTab
        org={ORG}
        data={{
          students: [{
            studentId: STUDENT,
            name: "Omar K.",
            studafyId: "SJ-0A1B2C3D4E",
            email: "omar@example.test",
            joinedOn: null,
            parents: [{
              name: "Lina K.",
              email: "lina@example.test",
              relationship: "parent",
            }],
          }],
        }}
      />,
    );
    for (
      const text of [
        "Omar K.",
        "SJ-0A1B2C3D4E",
        "omar@example.test",
        "Lina K.",
        "lina@example.test",
      ]
    ) {
      expect(html).toContain(text);
    }
    expect(render(<StudentsTab data={{ students: [] }} org={ORG} />)).toContain(
      portalEn.students.empty,
    );
  });

  test("marks: unpublished in italics, AI suggestions labelled as such", () => {
    const html = render(
      <MarksTab
        data={{
          items: [{
            id: ITEM,
            title: "Quiz 1",
            maximumScore: 10,
            category: "quiz",
          }],
          marks: [{
            assessmentId: ITEM,
            studentId: STUDENT,
            score: 7,
            mark: "scored",
            state: "draft",
            feedback: null,
            publishedAt: null,
          }],
          suggestions: [{
            assessmentId: ITEM,
            studentId: STUDENT,
            questionId: null,
            suggestedScore: 8,
            maximumScore: 10,
          }],
          students: [{ studentId: STUDENT, name: "Omar K." }],
        }}
      />,
    );
    expect(html).toContain('class="unpublished"');
    expect(html).toMatch(
      /class="pill muted">AI suggestion(<!-- -->)?: (<!-- -->)?8</,
    );
    expect(
      render(
        <MarksTab
          data={{ items: [], marks: [], suggestions: [], students: [] }}
        />,
      ),
    )
      .toContain(portalEn.marks.empty);
  });

  test("attendance: one cell per student and day, and totals", () => {
    const html = render(
      <AttendanceTab
        data={{
          records: [
            {
              sessionId: ITEM,
              date: "2026-09-10",
              startsAt: "2026-09-10T08:00:00Z",
              studentId: STUDENT,
              name: "Omar K.",
              state: "absent",
              reason: null,
            },
            {
              sessionId: CLASS,
              date: "2026-09-11",
              startsAt: "2026-09-11T08:00:00Z",
              studentId: STUDENT,
              name: "Omar K.",
              state: "present",
              reason: null,
            },
          ],
        }}
      />,
    );
    expect(html).toContain('class="att absent"');
    expect(html).toContain("P 1 · A 1 · L 0 · E 0");
  });

  test("wellbeing, hand-ins and answers render their content as text", () => {
    const script = "<script>alert(1)</script>";
    const notes = render(
      <WellbeingTab
        data={{
          notes: [{
            id: ITEM,
            studentId: STUDENT,
            name: "Omar K.",
            kind: "concern",
            title: script,
            context: null,
            followUp: null,
            severity: "low",
            status: "open",
            createdAt: "2026-11-01T09:00:00Z",
            author: "Rania",
          }],
        }}
      />,
    );
    expect(notes).not.toContain("<script>");
    expect(notes).toContain("&lt;script&gt;");
    const handIns = render(
      <HandInsView
        data={{
          assignmentId: ITEM,
          handIns: [{
            studentId: STUDENT,
            name: "Omar K.",
            status: "submitted",
            submittedAt: "2026-11-01T09:00:00Z",
            excused: false,
            answerText: script,
            files: [],
          }],
        }}
        org={ORG}
      />,
    );
    expect(handIns).not.toContain("<script>");
    const answers = render(
      <AnswersView
        data={{
          testId: ITEM,
          questions: [{
            id: CLASS,
            position: 1,
            kind: "short_answer",
            prompt: "Name a river.",
            maximumScore: 5,
          }],
          attempts: [{
            attemptId: ITEM,
            studentId: STUDENT,
            name: "Omar K.",
            attemptNumber: 1,
            submittedAt: "2026-11-01T09:00:00Z",
            awardedScore: 4,
            feedback: null,
            needsMarking: false,
            answers: [{
              questionId: CLASS,
              answerText: "The Jordan",
              selected: null,
              autoScore: null,
              awardedScore: 4,
              feedback: null,
            }],
          }],
        }}
      />,
    );
    expect(answers).toContain("The Jordan");
    expect(answers).toContain("Name a river.");
  });
});

test("no portal screen ever writes user content as HTML", () => {
  const dir = join(import.meta.dir, "..", "src", "portal");
  const files = readdirSync(dir, { recursive: true }).map(String)
    .filter((file) => file.endsWith(".tsx") || file.endsWith(".ts"));
  for (const file of files) {
    const source = readFileSync(join(dir, file), "utf8");
    expect(source, file).not.toContain("dangerouslySetInnerHTML");
    expect(source, file).not.toMatch(/\.innerHTML\s*=/);
  }
});

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
  ClassOverviewTab,
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
import { SentList } from "../src/portal/pages/Announcements";
import { GroupsView } from "../src/portal/pages/Groups";
import { csvCell, fileName, toCsv } from "../src/portal/export";
import {
  attendanceRows,
  marksRows,
  rosterRows,
} from "../src/portal/pages/ClassPage";
import {
  CLASS_TABS,
  hrefFor,
  parseRoute,
  type Route,
} from "../src/portal/router";
import { Loader } from "../src/portal/ui";
import { AGREEMENT_VERSION } from "../src/portal/api";
import { CreateSchool } from "../src/portal/pages/CreateSchool";
import { Welcome } from "../src/portal/pages/Welcome";
import { Settings } from "../src/portal/pages/Settings";
import { SCHOOL_AGREEMENT_VERSION } from "@studafy/contracts";

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
    { name: "announcements", org: ORG },
    { name: "groups", org: ORG },
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
    // فصل is never a class; the glossary keeps it for a school term only.
    expect(text).not.toMatch(/فصل(?! الدراسي)|فصول(?! الدراسية)|ستدفاي/);
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

  test("announcements sent: who they were for, when, how many they reached", () => {
    expect(render(<SentList data={{ announcements: [] }} />)).toContain(
      portalEn.announcements.empty,
    );
    const html = render(
      <SentList
        data={{
          announcements: [{
            id: ITEM,
            title: "Sports day",
            body: "<b>Friday</b>",
            audience: "students_and_parents",
            classroomIds: null,
            createdAt: "2026-11-03T08:00:00Z",
            removed: true,
            school: "Cedar Grove",
            author: "Huda Saleh",
            recipients: 14,
          }],
        }}
      />,
    );
    expect(html).toContain("Sports day");
    expect(html).toContain(
      portalEn.announcements.audiences.students_and_parents,
    );
    expect(html).toContain("14");
    expect(html).toContain(portalEn.announcements.removed);
    expect(html).not.toContain("<b>Friday</b>");
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
    expect(html).toContain(`/o/${ORG}/classes/${CLASS}/overview`);
    expect(html).not.toContain(portalEn.classes.allTerms);
  });

  test("classes show their term and last activity, with a term filter once there are two", () => {
    const one = {
      name: "Grade 7 Science",
      grade: "7",
      section: "A",
      status: "active",
      timezone: "Asia/Amman",
      teachers: [{ id: "t", name: "Rania Haddad", role: "lead_teacher" }],
      students: 24,
    };
    const html = render(
      <ClassesView
        data={{
          classes: [
            {
              ...one,
              id: CLASS,
              term: {
                name: "Term 1",
                startsOn: "2026-09-01",
                endsOn: "2027-01-20",
              },
              lastActivityAt: "2026-11-05T10:20:00Z",
            },
            {
              ...one,
              id: STUDENT,
              name: "Grade 7 Science (summer)",
              term: {
                name: "Summer",
                startsOn: "2026-06-01",
                endsOn: "2026-08-20",
              },
              lastActivityAt: null,
            },
          ],
        }}
        org={ORG}
      />,
    );
    expect(html).toContain('<td dir="auto">Term 1</td>');
    expect(html).toContain("5 Nov 2026");
    expect(html).toContain(portalEn.classes.allTerms);
    expect(html).toContain('<option value="Summer">Summer</option>');
  });

  test("a class opens on its overview: what is coming up, marks and attendance", () => {
    expect(parseRoute(`/o/${ORG}/classes/${CLASS}`)).toEqual({
      name: "class",
      org: ORG,
      classroom: CLASS,
      tab: "overview",
    });
    const empty = render(
      <ClassOverviewTab
        org={ORG}
        classroom={CLASS}
        data={{
          monthStart: "2026-11-01",
          attendance: { records: 0, attended: 0, rate: null },
          averageMark: null,
          markedStudents: 0,
          upcomingAssignments: [],
          upcomingTests: [],
        }}
      />,
    );
    expect(empty).toContain(portalEn.classPage.overview.noWork);
    expect(empty).toContain(portalEn.classPage.overview.noTests);
    const html = render(
      <ClassOverviewTab
        org={ORG}
        classroom={CLASS}
        data={{
          monthStart: "2026-11-01",
          attendance: { records: 40, attended: 37, rate: 0.925 },
          averageMark: 0.71,
          markedStudents: 20,
          upcomingAssignments: [{
            id: ITEM,
            title: "Essay on rivers",
            dueAt: "2026-11-09T18:00:00Z",
            handedIn: 3,
            students: 24,
          }],
          upcomingTests: [{
            id: STUDENT,
            title: "Rivers quiz",
            delivery: "online",
            at: "2026-11-12T08:00:00Z",
            maximumScore: 10,
          }],
        }}
      />,
    );
    expect(html).toContain("93%");
    expect(html).toContain("71%");
    expect(html).toContain("3 / 24");
    expect(html).toContain(`/o/${ORG}/classes/${CLASS}/assignments/${ITEM}`);
    expect(html).toContain(`/o/${ORG}/classes/${CLASS}/tests/${STUDENT}`);
    expect(render(
      <ClassOverviewTab
        org={ORG}
        classroom={CLASS}
        data={{
          monthStart: "2026-11-01",
          attendance: { records: 40, attended: 37, rate: 0.925 },
          averageMark: null,
          markedStudents: 0,
          upcomingAssignments: [],
          upcomingTests: [],
        }}
      />,
      "ar",
    )).toContain("37 / 40");
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

describe("export", () => {
  test("a cell a spreadsheet would run as a formula is made harmless", () => {
    for (
      const formula of ['=HYPERLINK("x")', "+1", "-2+3", "@SUM(A1)", "\tx"]
    ) {
      expect(csvCell(formula).replace(/^"/, "").startsWith("'")).toBe(true);
    }
    expect(csvCell(-5)).toBe("-5");
    expect(csvCell("Omar, K.")).toBe('"Omar, K."');
    expect(csvCell('say "hi"')).toBe('"say ""hi"""');
    expect(csvCell(null)).toBe("");
  });

  test("files open in Excel with Arabic intact, and names are safe", () => {
    expect(toCsv([["عمر", 1]]).startsWith("\uFEFF")).toBe(true);
    expect(toCsv([["a", "b"], [1, 2]])).toBe("\uFEFFa,b\r\n1,2\r\n");
    expect(fileName("Grade 7/Science", "Marks?")).toBe(
      "Grade 7Science - Marks.csv",
    );
  });

  test("rows say what the screen shows, in words", () => {
    const roster = rosterRows({
      students: [{
        studentId: STUDENT,
        name: "Omar K.",
        studafyId: "SJ-1",
        email: "o@x.test",
        joinedOn: null,
        parents: [{ name: "Lina", email: "l@x.test", relationship: "parent" }],
      }],
    }, portalEn);
    expect(roster[1]).toEqual([
      "Omar K.",
      "o@x.test",
      "SJ-1",
      "Lina <l@x.test>",
    ]);
    const marks = marksRows({
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
      suggestions: [],
      students: [{ studentId: STUDENT, name: "Omar K." }],
    }, portalEn);
    expect(marks).toEqual([["Student", "Quiz 1 (/10)"], [
      "Omar K.",
      "7 (Not published)",
    ]]);
    const attendance = attendanceRows({
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
      ],
    }, portalEn);
    expect(attendance[1]).toEqual(["Omar K.", "Absent", 0, 1, 0, 0]);
  });
});

describe("class groups", () => {
  const group = {
    id: ITEM,
    name: "Grade 7 – A",
    status: "active" as const,
    createdAt: "2026-11-02T08:00:00Z",
    code: "K7QM-4XTR",
    classes: [
      {
        id: STUDENT,
        classroomId: CLASS,
        name: "Grade 7 Science",
        teachers: [{ id: STUDENT, name: "Rania Haddad", role: "lead_teacher" }],
        status: "pending" as const,
        requestedAt: "2026-11-02T08:05:00Z",
        decidedAt: null,
      },
    ],
  };

  test("a group shows its code and each class waiting for its teacher", () => {
    const html = render(
      <GroupsView
        data={{ groups: [group] }}
        org={ORG}
        classes={[{ id: CLASS, name: "Grade 7 Science" }]}
        onChange={() => {}}
      />,
    );
    expect(html).toContain("K7QM-4XTR");
    expect(html).toContain(portalEn.groups.statuses.pending);
    expect(html).toContain("Rania Haddad");
    // The class is already in the group, so it isn't offered again.
    expect(html).not.toContain(portalEn.groups.add);
  });

  test("the picker tells one teacher's same-named classes apart", () => {
    const html = render(
      <GroupsView
        data={{ groups: [{ ...group, classes: [] }] }}
        org={ORG}
        classes={[
          {
            id: "c-9a",
            name: "Arabic",
            grade: "9",
            section: "A",
            teachers: [{ name: "Ahmad Saleh" }],
          },
          {
            id: "c-8b",
            name: "Arabic",
            grade: "8",
            section: "B",
            teachers: [{ name: "Ahmad Saleh" }],
          },
          {
            id: "c-8b-math",
            name: "Math",
            grade: "8",
            section: "B",
            teachers: [{ name: "Khalid Omar" }],
          },
        ]}
        onChange={() => {}}
      />,
    );
    // Grade 8 B's classes first, together, each with its teacher.
    const options = [...html.matchAll(/<option value="c-[^"]+">([^<]+)</g)]
      .map((m) => m[1]);
    expect(options).toEqual([
      "Arabic · 8 B · Ahmad Saleh",
      "Math · 8 B · Khalid Omar",
      "Arabic · 9 A · Ahmad Saleh",
    ]);
  });

  test("without a code key the code is never guessed at", () => {
    const html = render(
      <GroupsView
        data={{ groups: [{ ...group, code: null }] }}
        org={ORG}
        classes={[]}
        onChange={() => {}}
      />,
      "ar",
    );
    expect(html).toContain(portalAr.groups.noCode);
  });

  test("no groups yet says so", () => {
    expect(
      render(
        <GroupsView
          data={{ groups: [] }}
          org={ORG}
          classes={[]}
          onChange={() => {}}
        />,
      ),
    ).toContain(portalEn.groups.empty);
  });
});

describe("the School Agreement", () => {
  test("the portal sends the version the API expects", () => {
    expect(AGREEMENT_VERSION).toBe(SCHOOL_AGREEMENT_VERSION);
  });

  test("creating a school asks for it, linked, before Create can be pressed", () => {
    const html = render(
      <CreateSchool email="head@school.test" onCreated={() => {}} />,
    );
    expect(html).toContain(
      'href="https://legal.studafy.com/school-agreement" target="_blank"',
    );
    expect(html).toContain("Studafy School Agreement");
    expect(html).toMatch(/<button type="submit" class="btn" disabled=""/);
    expect(
      render(<CreateSchool email={null} onCreated={() => {}} />, "ar"),
    ).toContain('href="https://legal.studafy.com/ar/school-agreement"');
  });

  test("so does accepting an invitation", () => {
    const html = render(
      <Welcome
        invites={[{
          id: ITEM,
          jobTitle: "Deputy head",
          expiresAt: "2026-11-13T00:00:00.000Z",
          org: {
            id: ORG,
            name: "Cedar Grove",
            city: "Amman",
            country: "Jordan",
          },
          invitedBy: null,
        }]}
        onJoined={() => {}}
      />,
    );
    expect(html).toContain("/school-agreement");
    expect(html).toContain("Accept invitation");
    expect(html).toMatch(/disabled=""[^>]*>Accept invitation/);
  });
});

describe("administrators' invitations", () => {
  const admin = (n: number) => ({
    id: `5c900000-0000-4000-8000-00000000010${n}`,
    name: `Admin ${n}`,
    email: `admin${n}@school.test`,
    jobTitle: "Principal",
    addedAt: "2026-11-01T09:00:00Z",
  });
  const org = (admins: number) => ({
    id: ORG,
    name: "Cedar Grove",
    country: "Jordan",
    city: "Amman",
    kind: "private" as const,
    contactEmail: null,
    status: "active" as const,
    createdAt: "2026-11-01T09:00:00Z",
    admins: Array.from({ length: admins }, (_, i) => admin(i + 1)),
    invites: [{
      id: ITEM,
      email: "deputy@school.test",
      jobTitle: "Deputy head",
      expiresAt: "2026-11-12T09:00:00Z",
    }],
  });

  test("a pending invitation can be edited or cancelled", () => {
    const html = render(
      <Settings org={org(1) as never} me={admin(1).id} onChange={() => {}} />,
    );
    expect(html).toContain("deputy@school.test");
    expect(html).toContain(`>${portalEn.settings.editInvite}</button>`);
    expect(html).toContain(`>${portalEn.settings.revoke}</button>`);
    expect(html).toContain(portalEn.settings.inviteSend);
  });

  test("with every seat taken there is no new invitation, but the pending one can still be fixed", () => {
    const html = render(
      <Settings org={org(2) as never} me={admin(1).id} onChange={() => {}} />,
    );
    expect(html).not.toContain(portalEn.settings.inviteSend);
    expect(html).toContain(`>${portalEn.settings.editInvite}</button>`);
  });
});

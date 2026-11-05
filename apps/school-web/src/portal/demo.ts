/**
 * A click-through demo with invented data, for looking at the portal on a
 * developer's machine (`VITE_PORTAL_DEMO=true bun run dev`). It talks to no
 * server and no account. `import.meta.env.DEV` is false in every build, so
 * a deployed site can never be in demo mode.
 */
// Written out in full so the bundler replaces both with constants: in a
// build the condition is false and the demo is removed from the bundle.
export const DEMO = import.meta.env.DEV === true &&
  import.meta.env.VITE_PORTAL_DEMO === "true";

const ORG = "d0000000-0000-4000-8000-000000000001";
const ME = "d0000000-0000-4000-8000-000000000002";
const CLASSES = [
  {
    id: "d0000000-0000-4000-8000-000000000101",
    name: "Grade 7 Science",
    grade: "7",
    section: "A",
  },
  {
    id: "d0000000-0000-4000-8000-000000000102",
    name: "Grade 8 Mathematics",
    grade: "8",
    section: "B",
  },
];
const TEACHER = {
  id: "d0000000-0000-4000-8000-000000000201",
  name: "Rania Haddad",
  email: "rania@cedar.example",
};
const NAMES = [
  "Omar Khatib",
  "Lina Haddad",
  "Yousef Saleh",
  "Sara Nasser",
  "Adam Odeh",
  "Maya Fares",
];
const STUDENTS = NAMES.map((name, i) => ({
  studentId: `d0000000-0000-4000-8000-00000000030${i}`,
  name,
}));
const ITEMS = ["Quiz 1", "Unit 2 test", "Essay"].map((title, i) => ({
  id: `d0000000-0000-4000-8000-00000000040${i}`,
  title,
  maximumScore: i === 2 ? 20 : 10,
  category: i === 2 ? "assignment" : "quiz",
}));
const ASSIGNMENT = "d0000000-0000-4000-8000-000000000501";
const TEST = "d0000000-0000-4000-8000-000000000601";
const FILE = {
  fileId: "d0000000-0000-4000-8000-000000000701",
  name: "rivers-worksheet.pdf",
  sizeBytes: 182_000,
  mediaType: "application/pdf",
  scanState: "clean",
};
const DAYS = [
  "2026-11-01",
  "2026-11-02",
  "2026-11-03",
  "2026-11-04",
  "2026-11-05",
];
const STATES = [
  "present",
  "present",
  "late",
  "present",
  "absent",
  "excused",
] as const;

export const demoSession = {
  access_token: "demo",
  user: { id: ME, email: "principal@cedar.example" },
};

const org = {
  id: ORG,
  name: "Cedar Grove School",
  country: "Jordan",
  city: "Amman",
  kind: "private",
  contactEmail: "office@cedar.example",
  status: "active",
  createdAt: "2026-11-01T09:00:00Z",
  admins: [{
    id: ME,
    name: "Huda Saleh",
    email: "principal@cedar.example",
    jobTitle: "Principal",
    addedAt: "2026-11-01T09:00:00Z",
  }],
  invites: [],
};

/** The invented answer to one API call. */
export function demoAnswer(method: string, path: string): unknown {
  if (method === "POST") {
    if (path.endsWith("/download-intent")) {
      return { downloadUrl: "demo:", displayName: FILE.name };
    }
    return { id: ORG, orgId: ORG, linkId: ASSIGNMENT, status: "pending" };
  }
  if (path === "/v1/school-portal/orgs") return { orgs: [org] };
  if (path === "/v1/school-portal/invites") return { invites: [] };
  if (path.endsWith("/dashboard")) {
    return {
      linkedTeachers: 1,
      classes: 2,
      students: STUDENTS.length,
      waiting: [{
        id: "d0000000-0000-4000-8000-000000000901",
        teacher: {
          id: "d0000000-0000-4000-8000-000000000902",
          name: "Khaled Mansour",
          email: "khaled@cedar.example",
        },
        requestedAt: "2026-11-04T09:00:00Z",
      }],
    };
  }
  if (path.endsWith("/overview")) {
    return {
      classes: CLASSES.map((c, i) => ({
        classroomId: c.id,
        name: c.name,
        students: STUDENTS.length,
        attendanceRate: i === 0 ? 0.81 : 0.93,
        averageMark: i === 0 ? 0.72 : 0.64,
        missing: i === 0 ? 5 : 1,
      })),
      attention: [
        {
          studentId: STUDENTS[4]!.studentId,
          name: STUDENTS[4]!.name,
          classroomId: CLASSES[0]!.id,
          className: CLASSES[0]!.name,
          reasons: ["attendance", "missing_work"],
          attendanceRate: 0.6,
          averageMark: 0.58,
          missing: 3,
        },
        {
          studentId: STUDENTS[1]!.studentId,
          name: STUDENTS[1]!.name,
          classroomId: CLASSES[1]!.id,
          className: CLASSES[1]!.name,
          reasons: ["low_marks"],
          attendanceRate: 0.95,
          averageMark: 0.42,
          missing: 0,
        },
      ],
    };
  }
  if (path.endsWith("/teachers")) {
    return {
      teachers: [
        {
          ...TEACHER,
          linkId: "d0000000-0000-4000-8000-000000000903",
          studafyId: "4821937560",
          status: "linked",
          requestedAt: "2026-11-02T09:00:00Z",
          decidedAt: "2026-11-02T10:00:00Z",
          endedAt: null,
          classes: 2,
        },
        {
          id: "d0000000-0000-4000-8000-000000000902",
          name: "Khaled Mansour",
          email: "khaled@cedar.example",
          linkId: "d0000000-0000-4000-8000-000000000901",
          studafyId: "5930481726",
          status: "pending",
          requestedAt: "2026-11-04T09:00:00Z",
          decidedAt: null,
          endedAt: null,
          classes: 0,
        },
      ],
    };
  }
  if (path.endsWith("/classes")) {
    return {
      classes: CLASSES.map((c) => ({
        ...c,
        status: "active",
        timezone: "Asia/Amman",
        teachers: [{
          id: TEACHER.id,
          name: TEACHER.name,
          role: "lead_teacher",
        }],
        students: STUDENTS.length,
      })),
    };
  }
  if (path.endsWith("/roster")) {
    return {
      students: STUDENTS.map((s, i) => ({
        ...s,
        studafyId: `SJ-0A1B2C3D${i}E`,
        email: `${s.name.split(" ")[0]!.toLowerCase()}@student.example`,
        joinedOn: "2026-09-01",
        parents: i % 2 ? [] : [{
          name: `Parent of ${s.name.split(" ")[0]}`,
          email: "parent@family.example",
          relationship: "parent",
        }],
      })),
    };
  }
  if (path.endsWith("/lessons")) {
    return {
      sessions: DAYS.map((d, i) => ({
        id: `d0000000-0000-4000-8000-00000000080${i}`,
        title: `Rivers, part ${i + 1}`,
        startsAt: `${d}T08:00:00Z`,
        endsAt: `${d}T09:00:00Z`,
        status: "completed",
      })),
      materials: [{
        id: "d0000000-0000-4000-8000-000000000811",
        title: "How rivers shape the land",
        type: "lesson",
        body: "Read pages 12–15 and answer the questions on the worksheet.",
        lessonSessionId: null,
        publishedAt: "2026-11-03T08:00:00Z",
        files: [FILE],
        links: [{
          title: "River animation",
          url: "https://example.com/rivers",
        }],
      }],
      announcements: [{
        id: "d0000000-0000-4000-8000-000000000821",
        title: "Field trip on Friday",
        body: "Bring a packed lunch and walking shoes.",
        audience: "both",
        important: true,
        publishedAt: "2026-11-04T07:00:00Z",
        files: [],
      }],
    };
  }
  if (path.endsWith("/hand-ins")) {
    return {
      assignmentId: ASSIGNMENT,
      handIns: STUDENTS.map((s, i) => ({
        ...s,
        status: i < 4 ? "submitted" : "not_handed_in",
        submittedAt: i < 4 ? "2026-11-04T18:00:00Z" : null,
        excused: false,
        answerText: i < 4
          ? "Rivers carve valleys by erosion and carry sediment downstream."
          : null,
        files: i === 0 ? [FILE] : [],
      })),
    };
  }
  if (path.endsWith("/assignments")) {
    return {
      assignments: [{
        id: ASSIGNMENT,
        title: "Essay on rivers",
        instructions: "300 words.",
        dueAt: "2026-11-06T18:00:00Z",
        closesAt: null,
        state: "published",
        publishedAt: "2026-11-02T08:00:00Z",
        handedIn: 4,
        students: STUDENTS.length,
        files: [],
      }],
    };
  }
  if (path.endsWith("/answers")) {
    return {
      testId: TEST,
      questions: [
        {
          id: "d0000000-0000-4000-8000-000000000611",
          position: 1,
          kind: "short_answer",
          prompt: "Name the longest river in Jordan.",
          maximumScore: 2,
        },
        {
          id: "d0000000-0000-4000-8000-000000000612",
          position: 2,
          kind: "essay",
          prompt: "Explain how a river forms a valley.",
          maximumScore: 8,
        },
      ],
      attempts: STUDENTS.slice(0, 3).map((s, i) => ({
        attemptId: `d0000000-0000-4000-8000-00000000062${i}`,
        ...s,
        attemptNumber: 1,
        submittedAt: "2026-11-03T09:00:00Z",
        awardedScore: 8 - i,
        feedback: null,
        needsMarking: false,
        answers: [
          {
            questionId: "d0000000-0000-4000-8000-000000000611",
            answerText: "The Jordan River",
            selected: null,
            autoScore: 2,
            awardedScore: 2,
            feedback: null,
          },
          {
            questionId: "d0000000-0000-4000-8000-000000000612",
            answerText:
              "Water erodes the rock over a long time, cutting a V-shaped valley.",
            selected: null,
            autoScore: null,
            awardedScore: 6 - i,
            feedback: i === 0 ? "Good use of the word erosion." : null,
          },
        ],
      })),
    };
  }
  if (path.endsWith("/tests")) {
    return {
      tests: [{
        id: TEST,
        title: "Rivers quiz",
        category: "quiz",
        delivery: "online",
        state: "published",
        maximumScore: 10,
        scheduledAt: "2026-11-03T09:00:00Z",
        opensAt: null,
        closesAt: null,
        sat: 3,
        averageScore: 7,
      }],
    };
  }
  if (path.endsWith("/marks")) {
    return {
      items: ITEMS,
      marks: STUDENTS.flatMap((s, si) =>
        ITEMS.map((it, ii) => ({
          assessmentId: it.id,
          studentId: s.studentId,
          score: Math.max(2, it.maximumScore - ((si * 3 + ii * 2) % 6)),
          mark: "scored",
          state: ii === 2 && si % 2 ? "draft" : "published",
          feedback: null,
          publishedAt: null,
        }))
      ),
      suggestions: [{
        assessmentId: ITEMS[2]!.id,
        studentId: STUDENTS[1]!.studentId,
        questionId: null,
        suggestedScore: 16,
        maximumScore: 20,
      }],
      students: STUDENTS,
    };
  }
  if (path.endsWith("/attendance")) {
    return {
      records: STUDENTS.flatMap((s, si) =>
        DAYS.map((d, di) => ({
          sessionId: `d0000000-0000-4000-8000-0000000010${si}${di}`,
          date: d,
          startsAt: `${d}T08:00:00Z`,
          ...s,
          state: STATES[(si + di) % 6]!,
          reason: null,
        }))
      ),
    };
  }
  if (path.endsWith("/wellbeing")) {
    return {
      notes: [
        {
          id: "d0000000-0000-4000-8000-000000001101",
          studentId: STUDENTS[0]!.studentId,
          name: STUDENTS[0]!.name,
          kind: "strength",
          title: "Leads group work well",
          context: "Helped two classmates finish the river model.",
          followUp: null,
          severity: "low",
          status: "open",
          createdAt: "2026-11-03T10:00:00Z",
          author: TEACHER.name,
        },
        {
          id: "d0000000-0000-4000-8000-000000001102",
          studentId: STUDENTS[4]!.studentId,
          name: STUDENTS[4]!.name,
          kind: "concern",
          title: "Tired in morning lessons",
          context: "Often yawning in first period this week.",
          followUp: "Check in with Adam on Monday.",
          severity: "low",
          status: "open",
          createdAt: "2026-11-04T10:00:00Z",
          author: TEACHER.name,
        },
      ],
    };
  }
  return { orgs: [] };
}

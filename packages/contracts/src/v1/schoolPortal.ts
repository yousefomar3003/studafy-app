import { z } from "zod";

const Id = z.string().uuid();
const Timestamp = z.string().datetime({ offset: true });
const Email = z.string().trim().toLowerCase().email().max(254);
const CaptchaToken = z.string().min(1).max(2048).optional();

/**
 * Studafy School Portal (docs/planning/school-portal.md). A school's page
 * has up to three administrators, who sign in on the website. They ask a
 * teacher to link by the teacher's Studafy ID; the teacher accepts or
 * declines in the app. While linked, the administrators READ every class
 * the teacher teaches. Nothing here changes a class. Messages, AI Tutor
 * material and students' own notes are never part of any response.
 */

export const V1SchoolPortalOrgKind = z.enum([
  "public",
  "private",
  "international",
  "other",
]);
export const V1SchoolPortalOrgStatus = z.enum([
  "active",
  "suspended",
  "closed",
]);
export const V1SchoolPortalLinkStatus = z.enum([
  "pending",
  "linked",
  "declined",
  "cancelled",
  "expired",
  "unlinked",
]);

/** A person as the portal shows them: name and email only. */
export const V1SchoolPortalPerson = z.object({
  id: Id,
  name: z.string(),
  email: z.string().nullable(),
});

// ---------------------------------------------------------------------------
// Schools and administrators.
// ---------------------------------------------------------------------------

export const V1SchoolPortalAdmin = V1SchoolPortalPerson.extend({
  jobTitle: z.string(),
  addedAt: Timestamp,
});

export const V1SchoolPortalInvite = z.object({
  id: Id,
  email: z.string(),
  jobTitle: z.string(),
  expiresAt: Timestamp,
});

export const V1SchoolPortalOrg = z.object({
  id: Id,
  name: z.string(),
  country: z.string(),
  city: z.string(),
  kind: V1SchoolPortalOrgKind,
  contactEmail: z.string().nullable(),
  status: V1SchoolPortalOrgStatus,
  createdAt: Timestamp,
  admins: z.array(V1SchoolPortalAdmin).max(3),
  invites: z.array(V1SchoolPortalInvite).max(3),
});

export const V1SchoolPortalOrgs = z.object({
  orgs: z.array(V1SchoolPortalOrg).max(100),
});
export type V1SchoolPortalOrgs = z.infer<typeof V1SchoolPortalOrgs>;

const OrgFields = {
  name: z.string().trim().min(2).max(120),
  country: z.string().trim().min(2).max(80),
  city: z.string().trim().min(1).max(80),
  kind: V1SchoolPortalOrgKind,
  contactEmail: Email.nullable().optional(),
};

export const V1CreateSchoolPortalOrgRequest = z.strictObject({
  ...OrgFields,
  /** The creator's own role at the school, shown to teachers they ask. */
  jobTitle: z.string().trim().min(2).max(80),
  captchaToken: CaptchaToken,
});
export const V1UpdateSchoolPortalOrgRequest = z.strictObject({
  name: OrgFields.name.optional(),
  country: OrgFields.country.optional(),
  city: OrgFields.city.optional(),
  kind: V1SchoolPortalOrgKind.optional(),
  contactEmail: Email.nullable().optional(),
});
export const V1SchoolPortalOrgResult = z.object({
  id: Id,
  status: V1SchoolPortalOrgStatus.optional(),
});

export const V1InviteSchoolPortalAdminRequest = z.strictObject({
  email: Email,
  jobTitle: z.string().trim().min(2).max(80),
});
export const V1SchoolPortalInviteResult = z.object({ id: Id });

/** Invites addressed to the signed-in person's email. */
export const V1SchoolPortalMyInvites = z.object({
  invites: z.array(z.object({
    id: Id,
    jobTitle: z.string(),
    expiresAt: Timestamp,
    org: z.object({
      id: Id,
      name: z.string(),
      city: z.string(),
      country: z.string(),
    }),
    invitedBy: V1SchoolPortalPerson.nullable(),
  })).max(50),
});
export const V1SchoolPortalEmptyRequest = z.strictObject({});
export const V1SchoolPortalOrgRef = z.object({
  orgId: Id,
  status: V1SchoolPortalOrgStatus.optional(),
});
export const V1RemoveSchoolPortalAdminRequest = z.strictObject({
  userId: Id,
});

// ---------------------------------------------------------------------------
// Links with teachers.
// ---------------------------------------------------------------------------

export const V1RequestSchoolPortalLinkRequest = z.strictObject({
  /** The teacher's Studafy ID: ten digits, shown in their app. */
  studafyId: z.string().trim().regex(/^[1-9][0-9]{9}$/),
  captchaToken: CaptchaToken,
});
export const V1SchoolPortalLinkRequested = z.object({
  linkId: Id,
  teacher: V1SchoolPortalPerson,
  status: z.literal("pending"),
});
export const V1SchoolPortalLinkResult = z.object({
  linkId: Id,
  status: V1SchoolPortalLinkStatus,
  /** The link that ended because the teacher moved to this school. */
  replaced: Id.nullable().optional(),
});

export const V1SchoolPortalDashboard = z.object({
  linkedTeachers: z.number().int().nonnegative(),
  classes: z.number().int().nonnegative(),
  students: z.number().int().nonnegative(),
  waiting: z.array(z.object({
    id: Id,
    teacher: V1SchoolPortalPerson,
    requestedAt: Timestamp,
  })).max(500),
});

export const V1SchoolPortalTeachers = z.object({
  teachers: z.array(V1SchoolPortalPerson.extend({
    linkId: Id,
    studafyId: z.string().nullable(),
    status: V1SchoolPortalLinkStatus,
    requestedAt: Timestamp,
    decidedAt: Timestamp.nullable(),
    endedAt: Timestamp.nullable(),
    classes: z.number().int().nonnegative(),
  })).max(5000),
});

// ---------------------------------------------------------------------------
// Classes (read-only).
// ---------------------------------------------------------------------------

export const V1SchoolPortalClass = z.object({
  id: Id,
  name: z.string(),
  grade: z.string().nullable(),
  section: z.string().nullable(),
  status: z.string(),
  timezone: z.string(),
  teachers: z.array(z.object({ id: Id, name: z.string(), role: z.string() }))
    .max(50),
  students: z.number().int().nonnegative(),
});
export const V1SchoolPortalClasses = z.object({
  classes: z.array(V1SchoolPortalClass).max(5000),
});

const PortalFile = z.object({
  fileId: Id,
  name: z.string().nullable(),
  sizeBytes: z.number().int().nonnegative().nullable(),
  mediaType: z.string().nullable(),
  scanState: z.string(),
});

export const V1SchoolPortalRoster = z.object({
  students: z.array(z.object({
    studentId: Id,
    name: z.string(),
    studafyId: z.string().nullable(),
    email: z.string().nullable(),
    joinedOn: z.string().nullable(),
    parents: z.array(z.object({
      name: z.string(),
      email: z.string().nullable(),
      relationship: z.string().nullable(),
    })).max(20),
  })).max(5000),
});

export const V1SchoolPortalLessons = z.object({
  sessions: z.array(z.object({
    id: Id,
    title: z.string().nullable(),
    startsAt: Timestamp,
    endsAt: Timestamp,
    status: z.string(),
  })).max(500),
  materials: z.array(z.object({
    id: Id,
    title: z.string(),
    type: z.string(),
    body: z.string().nullable(),
    lessonSessionId: Id.nullable(),
    publishedAt: Timestamp.nullable(),
    files: z.array(PortalFile).max(100),
    links: z.array(z.object({ title: z.string().nullable(), url: z.string() }))
      .max(100),
  })).max(5000),
  announcements: z.array(z.object({
    id: Id,
    title: z.string(),
    body: z.string(),
    audience: z.string(),
    important: z.boolean(),
    publishedAt: Timestamp,
    files: z.array(PortalFile).max(100),
  })).max(5000),
});

export const V1SchoolPortalAssignments = z.object({
  assignments: z.array(z.object({
    id: Id,
    title: z.string(),
    instructions: z.string().nullable(),
    dueAt: Timestamp.nullable(),
    closesAt: Timestamp.nullable(),
    state: z.string(),
    publishedAt: Timestamp.nullable(),
    handedIn: z.number().int().nonnegative(),
    students: z.number().int().nonnegative(),
    files: z.array(PortalFile).max(100),
  })).max(5000),
});

export const V1SchoolPortalHandIns = z.object({
  assignmentId: Id,
  handIns: z.array(z.object({
    studentId: Id,
    name: z.string(),
    status: z.string(),
    submittedAt: Timestamp.nullable(),
    excused: z.boolean(),
    answerText: z.string().nullable(),
    files: z.array(PortalFile).max(100),
  })).max(5000),
});

export const V1SchoolPortalTests = z.object({
  tests: z.array(z.object({
    id: Id,
    title: z.string(),
    category: z.string(),
    delivery: z.string(),
    state: z.string(),
    maximumScore: z.number(),
    scheduledAt: Timestamp.nullable(),
    opensAt: Timestamp.nullable(),
    closesAt: Timestamp.nullable(),
    sat: z.number().int().nonnegative(),
    averageScore: z.number().nullable(),
  })).max(5000),
});

export const V1SchoolPortalTestAnswers = z.object({
  testId: Id,
  questions: z.array(z.object({
    id: Id,
    position: z.number().int(),
    kind: z.string().nullable(),
    prompt: z.string().nullable(),
    maximumScore: z.number(),
  })).max(500),
  attempts: z.array(z.object({
    attemptId: Id,
    studentId: Id,
    name: z.string(),
    attemptNumber: z.number().int().nullable(),
    submittedAt: Timestamp,
    awardedScore: z.number().nullable(),
    feedback: z.string().nullable(),
    needsMarking: z.boolean().nullable(),
    answers: z.array(z.object({
      questionId: Id,
      answerText: z.string().nullable(),
      selected: z.unknown().nullable(),
      autoScore: z.number().nullable(),
      awardedScore: z.number().nullable(),
      feedback: z.string().nullable(),
    })).max(500),
  })).max(20000),
});

export const V1SchoolPortalMarks = z.object({
  items: z.array(z.object({
    id: Id,
    title: z.string(),
    maximumScore: z.number(),
    category: z.string(),
  })).max(5000),
  /** Every mark, with its state: draft, reviewed, published or withdrawn. */
  marks: z.array(z.object({
    assessmentId: Id,
    studentId: Id,
    score: z.number().nullable(),
    mark: z.string(),
    state: z.string(),
    feedback: z.string().nullable(),
    publishedAt: Timestamp.nullable(),
  })).max(100000),
  /** Studafy AI Marking suggestions, labelled as such. */
  suggestions: z.array(z.object({
    assessmentId: Id,
    studentId: Id,
    questionId: Id.nullable(),
    suggestedScore: z.number().nullable(),
    maximumScore: z.number(),
  })).max(100000),
  students: z.array(z.object({ studentId: Id, name: z.string() })).max(5000),
});

export const V1SchoolPortalAttendance = z.object({
  records: z.array(z.object({
    sessionId: Id,
    /** The lesson's date in the class's school time zone. */
    date: z.string(),
    startsAt: Timestamp,
    studentId: Id,
    name: z.string(),
    state: z.enum(["present", "absent", "late", "excused"]),
    reason: z.string().nullable(),
  })).max(200000),
});

export const V1SchoolPortalWellbeing = z.object({
  notes: z.array(z.object({
    id: Id,
    studentId: Id,
    name: z.string(),
    kind: z.string(),
    title: z.string(),
    context: z.string().nullable(),
    followUp: z.string().nullable(),
    severity: z.string(),
    status: z.string(),
    createdAt: Timestamp,
    author: z.string().nullable(),
  })).max(20000),
});

// ---------------------------------------------------------------------------
// The teacher's side, in the app.
// ---------------------------------------------------------------------------

export const V1MySchoolLinks = z.object({
  links: z.array(z.object({
    id: Id,
    status: V1SchoolPortalLinkStatus,
    requestedAt: Timestamp,
    decidedAt: Timestamp.nullable(),
    endedAt: Timestamp.nullable(),
    org: z.object({
      id: Id,
      name: z.string(),
      city: z.string(),
      country: z.string(),
      kind: V1SchoolPortalOrgKind,
      status: V1SchoolPortalOrgStatus,
    }),
    requestedBy: V1SchoolPortalPerson.extend({
      jobTitle: z.string().nullable(),
    }).nullable(),
  })).max(500),
});
export type V1MySchoolLinks = z.infer<typeof V1MySchoolLinks>;

export const V1DecideSchoolLinkRequest = z.strictObject({
  decision: z.enum(["accept", "decline"]),
  /**
   * One school at a time: accepting while linked elsewhere answers 409
   * LINKED_ELSEWHERE until the teacher agrees to leave the current school.
   */
  replaceCurrent: z.boolean().optional(),
});

export const V1ReportSchoolRequest = z.strictObject({
  reason: z.enum(["not_my_school", "fake_school", "pressure", "other"]),
  details: z.string().trim().max(1000).optional(),
});
export const V1ReportSchoolResult = z.object({ reportId: Id });

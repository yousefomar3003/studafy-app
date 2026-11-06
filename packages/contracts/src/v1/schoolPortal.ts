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

/**
 * The School Agreement's current version (docs/legal/school-agreement.md);
 * private.school_portal_agreement_version() says the same.
 */
export const SCHOOL_AGREEMENT_VERSION = "2026-11-06";
/** Each administrator accepts the current agreement, and it is recorded. */
const AgreementVersion = z.literal(SCHOOL_AGREEMENT_VERSION);

export const V1CreateSchoolPortalOrgRequest = z.strictObject({
  ...OrgFields,
  /** The creator's own role at the school, shown to teachers they ask. */
  jobTitle: z.string().trim().min(2).max(80),
  /** "I am an adult": recorded once for an account nothing has decided. */
  adult: z.literal(true),
  agreementVersion: AgreementVersion,
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
/** Accepting an administrator invite, as an adult (as creating a school). */
export const V1AcceptSchoolPortalInviteRequest = z.strictObject({
  adult: z.literal(true),
  agreementVersion: AgreementVersion,
});
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
  /**
   * The teacher's Studafy ID, as their app shows it ("TC-" and ten digits)
   * or the ten digits alone.
   */
  studafyId: z.string().trim().regex(/^(?:TC-)?[1-9][0-9]{9}$/i),
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

/** The school at a glance (plan 13a.1). Rates and marks are 0–1. */
export const V1SchoolPortalAttentionReason = z.enum([
  "attendance",
  "missing_work",
  "low_marks",
]);
export const V1SchoolPortalOverview = z.object({
  classes: z.array(z.object({
    classroomId: Id,
    name: z.string(),
    students: z.number().int().nonnegative(),
    attendanceRate: z.number().nullable(),
    averageMark: z.number().nullable(),
    missing: z.number().int().nonnegative(),
  })).max(5000),
  attention: z.array(z.object({
    studentId: Id,
    name: z.string(),
    classroomId: Id,
    className: z.string(),
    reasons: z.array(V1SchoolPortalAttentionReason).min(1).max(3),
    attendanceRate: z.number().nullable(),
    averageMark: z.number().nullable(),
    missing: z.number().int().nonnegative(),
  })).max(20000),
});

const ClassNumbers = {
  classroomId: Id,
  name: z.string(),
  attendanceRate: z.number().nullable(),
  averageMark: z.number().nullable(),
  missing: z.number().int().nonnegative(),
};

/** One student across every visible class (plan 13a.2). */
export const V1SchoolPortalStudent = z.object({
  student: z.object({
    studentId: Id,
    name: z.string(),
    studafyId: z.string().nullable(),
    email: z.string().nullable(),
    parents: z.array(z.object({
      name: z.string(),
      email: z.string().nullable(),
      relationship: z.string().nullable(),
    })).max(20),
  }),
  classes: z.array(z.object({
    ...ClassNumbers,
    teachers: z.array(z.string()).max(50),
  })).max(200),
  recentMarks: z.array(z.object({
    assessmentId: Id,
    title: z.string(),
    className: z.string(),
    score: z.number().nullable(),
    maximumScore: z.number(),
    mark: z.string(),
    state: z.string(),
    at: Timestamp,
  })).max(20),
  missingWork: z.array(z.object({
    assignmentId: Id,
    title: z.string(),
    className: z.string(),
    dueAt: Timestamp.nullable(),
  })).max(1000),
  wellbeing: z.array(z.object({
    id: Id,
    className: z.string(),
    kind: z.string(),
    title: z.string(),
    context: z.string().nullable(),
    createdAt: Timestamp,
  })).max(1000),
});

/** One linked teacher (plan 13a.3). */
export const V1SchoolPortalTeacher = z.object({
  teacher: V1SchoolPortalPerson.extend({
    studafyId: z.string().nullable(),
    linkedSince: Timestamp.nullable(),
  }),
  classes: z.array(z.object({
    ...ClassNumbers,
    students: z.number().int().nonnegative(),
  })).max(500),
  recentLessons: z.array(z.object({
    id: Id,
    title: z.string().nullable(),
    className: z.string(),
    startsAt: Timestamp,
    status: z.string(),
  })).max(10),
  toMark: z.object({
    testAnswers: z.number().int().nonnegative(),
    handIns: z.number().int().nonnegative(),
  }),
});

const Week = z.object({
  /** The Monday the week starts on (YYYY-MM-DD, UTC). */
  weekStart: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  attendanceRate: z.number().nullable(),
});

/** Reports across classes (plan 13a.4). Rates and marks are 0–1. */
export const V1SchoolPortalReports = z.object({
  weeks: z.array(Week).length(12),
  classes: z.array(z.object({
    classroomId: Id,
    name: z.string(),
    students: z.number().int().nonnegative(),
    attendanceRate: z.number().nullable(),
    averageMark: z.number().nullable(),
    handInRate: z.number().nullable(),
    bands: z.object({
      below50: z.number().int().nonnegative(),
      from50: z.number().int().nonnegative(),
      from70: z.number().int().nonnegative(),
      from85: z.number().int().nonnegative(),
    }),
    weeks: z.array(Week).length(12),
  })).max(5000),
});

/**
 * An export about to be made by the website (plan 13a.5): recorded in the
 * activity record first; the file is built only after this succeeds.
 */
export const V1RecordSchoolPortalExportRequest = z.strictObject({
  kind: z.enum(["students", "marks", "attendance", "reports", "class"]),
  format: z.enum(["csv", "pdf"]),
  /** Required for every kind except "reports". */
  classroomId: Id.optional(),
});
export const V1RecordSchoolPortalExportResult = z.object({
  recorded: z.literal(true),
});

/** Who a school's announcement is for (plan 13a.6); never one student. */
export const V1SchoolAnnouncementAudience = z.enum([
  "students",
  "parents",
  "students_and_parents",
  "teachers",
]);

export const V1SchoolAnnouncement = z.object({
  id: Id,
  title: z.string(),
  body: z.string(),
  audience: V1SchoolAnnouncementAudience,
  /** Null: every linked class. */
  classroomIds: z.array(Id).nullable(),
  createdAt: Timestamp,
  removed: z.boolean(),
  school: z.string(),
  author: z.string().nullable(),
});

export const V1SchoolPortalAnnouncements = z.object({
  announcements: z.array(V1SchoolAnnouncement.extend({
    recipients: z.number().int().nonnegative(),
  })).max(200),
});

export const V1SendSchoolPortalAnnouncementRequest = z.strictObject({
  title: z.string().trim().min(1).max(120),
  body: z.string().trim().min(1).max(4000),
  audience: V1SchoolAnnouncementAudience,
  /** Omitted: every linked class. */
  classroomIds: z.array(Id).min(1).max(500).optional(),
});
export const V1SendSchoolPortalAnnouncementResult = z.object({
  id: Id,
  recipients: z.number().int().nonnegative(),
});

/** Announcements that reach the signed-in person, from any school. */
export const V1MySchoolAnnouncements = z.object({
  announcements: z.array(V1SchoolAnnouncement).max(500),
});

// ---------------------------------------------------------------------------
// One code for many classes (plan 13a.7). The school groups linked classes;
// each class's teacher approves; a student types the group's code in the
// app's "Join a class" and joins every approved class.
// ---------------------------------------------------------------------------

/** The same form as a class code: `ABCD-EFGH`. */
const GroupCode = z.string().regex(/^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$/);

export const V1SchoolPortalGroupClassStatus = z.enum([
  "pending",
  "approved",
  "declined",
]);

export const V1SchoolPortalGroup = z.object({
  id: Id,
  name: z.string(),
  status: z.literal("active"),
  createdAt: Timestamp,
  /** Null when the server has no code key. */
  code: GroupCode.nullable(),
  classes: z.array(z.object({
    /** The class's place in the group (not the class's id). */
    id: Id,
    classroomId: Id,
    name: z.string(),
    teachers: z.array(z.object({ id: Id, name: z.string(), role: z.string() }))
      .max(50),
    status: V1SchoolPortalGroupClassStatus,
    requestedAt: Timestamp,
    decidedAt: Timestamp.nullable(),
  })).max(60),
});
export const V1SchoolPortalGroups = z.object({
  groups: z.array(V1SchoolPortalGroup).max(50),
});

export const V1CreateSchoolPortalGroupRequest = z.strictObject({
  name: z.string().trim().min(1).max(80),
});
export const V1SchoolPortalGroupClassRequest = z.strictObject({
  classroomId: Id,
});
export const V1CloseSchoolPortalGroupResult = z.object({
  id: Id,
  status: z.literal("closed"),
});

/** A class of the teacher's that a school asked to add to a group. */
export const V1MySchoolGroupClass = z.object({
  id: Id,
  status: z.enum(["pending", "approved"]),
  groupName: z.string(),
  school: z.string(),
  classroomId: Id,
  className: z.string(),
  requestedAt: Timestamp,
  decidedAt: Timestamp.nullable(),
});
export const V1MySchoolGroupClasses = z.object({
  classes: z.array(V1MySchoolGroupClass).max(500),
});
export const V1DecideMySchoolGroupClassRequest = z.strictObject({
  /** `remove` takes an approved class out of the group. */
  decision: z.enum(["approve", "decline", "remove"]),
});
export const V1DecideMySchoolGroupClassResult = z.object({
  id: Id,
  status: z.enum(["approved", "declined", "removed"]),
});

import type * as C from "@studafy/contracts";
import type { z } from "zod";
import { accessToken } from "./auth";
import { portalConfig } from "./config";
import { DEMO, demoAnswer } from "./demo";

/** A refusal from the API: its status and its stable code. */
export class ApiError extends Error {
  constructor(readonly status: number, readonly code: string) {
    super(code);
  }
}

type Of<T extends z.ZodType> = z.infer<T>;
export type Orgs = Of<typeof C.V1SchoolPortalOrgs>;
export type Org = Orgs["orgs"][number];
export type MyInvites = Of<typeof C.V1SchoolPortalMyInvites>;
export type Dashboard = Of<typeof C.V1SchoolPortalDashboard>;
export type Teachers = Of<typeof C.V1SchoolPortalTeachers>;
export type Classes = Of<typeof C.V1SchoolPortalClasses>;
export type Roster = Of<typeof C.V1SchoolPortalRoster>;
export type Lessons = Of<typeof C.V1SchoolPortalLessons>;
export type Assignments = Of<typeof C.V1SchoolPortalAssignments>;
export type HandIns = Of<typeof C.V1SchoolPortalHandIns>;
export type Tests = Of<typeof C.V1SchoolPortalTests>;
export type TestAnswers = Of<typeof C.V1SchoolPortalTestAnswers>;
export type Marks = Of<typeof C.V1SchoolPortalMarks>;
export type Attendance = Of<typeof C.V1SchoolPortalAttendance>;
export type Wellbeing = Of<typeof C.V1SchoolPortalWellbeing>;
export type Overview = Of<typeof C.V1SchoolPortalOverview>;
export type StudentPage = Of<typeof C.V1SchoolPortalStudent>;
export type TeacherPage = Of<typeof C.V1SchoolPortalTeacher>;
export type Reports = Of<typeof C.V1SchoolPortalReports>;
export type CreateOrgRequest = Of<typeof C.V1CreateSchoolPortalOrgRequest>;
export type PortalFile = Lessons["materials"][number]["files"][number];

async function request<T>(
  method: "GET" | "POST",
  path: string,
  body?: unknown,
): Promise<T> {
  if (DEMO) return demoAnswer(method, path) as T;
  const token = await accessToken();
  if (!token) throw new ApiError(401, "UNAUTHENTICATED");
  const headers: Record<string, string> = { Authorization: `Bearer ${token}` };
  if (method === "POST") {
    headers["Content-Type"] = "application/json";
    // One key per tap: a retry of the same tap is a new request.
    headers["Idempotency-Key"] = crypto.randomUUID();
  }
  let response: Response;
  try {
    response = await fetch(`${portalConfig.apiUrl}${path}`, {
      method,
      headers,
      ...(method === "POST" ? { body: JSON.stringify(body ?? {}) } : {}),
    });
  } catch {
    throw new ApiError(0, "NETWORK");
  }
  if (!response.ok) {
    let code = "INTERNAL_ERROR";
    try {
      code = String(
        ((await response.json()) as { code?: unknown }).code ?? code,
      );
    } catch { /* not JSON: keep the generic code */ }
    throw new ApiError(response.status, code);
  }
  return await response.json() as T;
}

const org = (id: string) => `/v1/school-portal/orgs/${encodeURIComponent(id)}`;
const id = encodeURIComponent;

export const api = {
  orgs: () => request<Orgs>("GET", "/v1/school-portal/orgs"),
  myInvites: () => request<MyInvites>("GET", "/v1/school-portal/invites"),
  createOrg: (body: CreateOrgRequest) =>
    request<{ id: string }>("POST", "/v1/school-portal/orgs", body),
  updateOrg: (orgId: string, body: Partial<CreateOrgRequest>) =>
    request<{ id: string }>("POST", org(orgId), body),
  closeOrg: (orgId: string) => request("POST", `${org(orgId)}/close`, {}),
  inviteAdmin: (orgId: string, email: string, jobTitle: string) =>
    request("POST", `${org(orgId)}/admins`, { email, jobTitle }),
  removeAdmin: (orgId: string, userId: string) =>
    request("POST", `${org(orgId)}/admins/remove`, { userId }),
  acceptInvite: (inviteId: string) =>
    request<{ orgId: string }>(
      "POST",
      `/v1/school-portal/invites/${id(inviteId)}/accept`,
      { adult: true },
    ),
  dashboard: (orgId: string) =>
    request<Dashboard>("GET", `${org(orgId)}/dashboard`),
  overview: (orgId: string) =>
    request<Overview>("GET", `${org(orgId)}/overview`),
  reports: (orgId: string) => request<Reports>("GET", `${org(orgId)}/reports`),
  student: (orgId: string, studentId: string) =>
    request<StudentPage>("GET", `${org(orgId)}/students/${id(studentId)}`),
  teacher: (orgId: string, teacherId: string) =>
    request<TeacherPage>("GET", `${org(orgId)}/teachers/${id(teacherId)}`),
  teachers: (orgId: string) =>
    request<Teachers>("GET", `${org(orgId)}/teachers`),
  requestLink: (orgId: string, studafyId: string, captchaToken?: string) =>
    request("POST", `${org(orgId)}/link-requests`, {
      studafyId,
      ...(captchaToken ? { captchaToken } : {}),
    }),
  cancelLink: (orgId: string, linkId: string) =>
    request("POST", `${org(orgId)}/link-requests/${id(linkId)}/cancel`, {}),
  unlinkTeacher: (orgId: string, linkId: string) =>
    request("POST", `${org(orgId)}/teachers/${id(linkId)}/unlink`, {}),
  classes: (orgId: string) => request<Classes>("GET", `${org(orgId)}/classes`),
  roster: (orgId: string, classId: string) =>
    request<Roster>("GET", `${org(orgId)}/classes/${id(classId)}/roster`),
  lessons: (orgId: string, classId: string) =>
    request<Lessons>("GET", `${org(orgId)}/classes/${id(classId)}/lessons`),
  assignments: (orgId: string, classId: string) =>
    request<Assignments>(
      "GET",
      `${org(orgId)}/classes/${id(classId)}/assignments`,
    ),
  handIns: (orgId: string, assignmentId: string) =>
    request<HandIns>(
      "GET",
      `${org(orgId)}/assignments/${id(assignmentId)}/hand-ins`,
    ),
  tests: (orgId: string, classId: string) =>
    request<Tests>("GET", `${org(orgId)}/classes/${id(classId)}/tests`),
  testAnswers: (orgId: string, testId: string) =>
    request<TestAnswers>("GET", `${org(orgId)}/tests/${id(testId)}/answers`),
  marks: (orgId: string, classId: string) =>
    request<Marks>("GET", `${org(orgId)}/classes/${id(classId)}/marks`),
  attendance: (orgId: string, classId: string) =>
    request<Attendance>(
      "GET",
      `${org(orgId)}/classes/${id(classId)}/attendance`,
    ),
  wellbeing: (orgId: string, classId: string) =>
    request<Wellbeing>("GET", `${org(orgId)}/classes/${id(classId)}/wellbeing`),
};

/**
 * Opens a file of a linked class: a single-use link from the API, then the
 * bytes fetched with the session (the link alone opens nothing) and shown
 * from memory, never stored.
 */
export async function openFile(orgId: string, file: PortalFile): Promise<void> {
  const intent = await request<{ downloadUrl: string; displayName: string }>(
    "POST",
    `${org(orgId)}/files/${id(file.fileId)}/download-intent`,
    {},
  );
  if (DEMO) return;
  const token = await accessToken();
  const response = await fetch(intent.downloadUrl, {
    headers: { Authorization: `Bearer ${token ?? ""}` },
  });
  if (!response.ok) throw new ApiError(response.status, "FILE_UNAVAILABLE");
  const url = URL.createObjectURL(await response.blob());
  const link = document.createElement("a");
  link.href = url;
  link.download = intent.displayName || file.name || "file";
  link.rel = "noopener";
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 60_000);
}

import { z } from "zod";

const Id = z.string().uuid();
const Version = z.number().int().positive();

export const V1SchoolAdmin = z.strictObject({
  id: Id,
  name: z.string().min(1).max(160),
  timezone: z.string().min(1).max(100),
  locale: z.enum(["en", "ar"]),
  status: z.enum(["provisioning", "active", "suspended", "closed"]),
  version: Version,
});
export type V1SchoolAdmin = z.infer<typeof V1SchoolAdmin>;

export const V1ProvisionSchoolRequest = z.strictObject({
  name: z.string().trim().min(1).max(160),
  timezone: z.string().trim().min(1).max(100).default("Asia/Riyadh"),
  locale: z.enum(["en", "ar"]).default("en"),
  initialAdminUserId: Id,
});
export type V1ProvisionSchoolRequest = z.infer<typeof V1ProvisionSchoolRequest>;

export const V1SchoolLifecycleRequest = z.strictObject({
  expectedVersion: Version,
  reason: z.string().trim().min(1).max(500).optional(),
});
export type V1SchoolLifecycleRequest = z.infer<typeof V1SchoolLifecycleRequest>;

export const V1MembershipRecord = z.strictObject({
  id: Id,
  schoolId: Id,
  userId: Id,
  role: z.enum(["school_admin", "teacher", "parent", "guardian", "student"]),
  status: z.enum(["invited", "active", "suspended", "revoked", "expired"]),
  version: Version,
});
export type V1MembershipRecord = z.infer<typeof V1MembershipRecord>;

export const V1GrantMembershipRequest = z.strictObject({
  userId: Id,
  role: z.enum(["school_admin", "teacher", "parent", "guardian", "student"]),
  reason: z.string().trim().min(1).max(500).optional(),
});
export type V1GrantMembershipRequest = z.infer<typeof V1GrantMembershipRequest>;

export const V1MembershipLifecycleRequest = z.strictObject({
  expectedVersion: Version,
  reason: z.string().trim().min(1).max(500).optional(),
});
export type V1MembershipLifecycleRequest = z.infer<
  typeof V1MembershipLifecycleRequest
>;

export const V1ClassroomStaffAssignment = z.strictObject({
  id: Id,
  classroomId: Id,
  userId: Id,
  role: z.enum(["lead_teacher", "co_teacher", "assistant"]),
  status: z.enum(["active", "ended"]),
});
export type V1ClassroomStaffAssignment = z.infer<
  typeof V1ClassroomStaffAssignment
>;

export const V1AssignClassroomStaffRequest = z.strictObject({
  userId: Id,
  role: z.enum(["lead_teacher", "co_teacher", "assistant"]),
});
export type V1AssignClassroomStaffRequest = z.infer<
  typeof V1AssignClassroomStaffRequest
>;

export const V1RemoveClassroomStaffRequest = z.strictObject({
  staffAssignmentId: Id,
});
export type V1RemoveClassroomStaffRequest = z.infer<
  typeof V1RemoveClassroomStaffRequest
>;

export const V1EnrollmentTransition = z.strictObject({
  classroomId: Id,
  studentId: Id,
  status: z.enum(["invited", "active", "withdrawn", "completed"]),
});
export type V1EnrollmentTransition = z.infer<typeof V1EnrollmentTransition>;

export const V1EnrollStudentRequest = z.strictObject({
  studentId: Id,
});
export type V1EnrollStudentRequest = z.infer<typeof V1EnrollStudentRequest>;

export const V1WithdrawStudentRequest = z.strictObject({
  studentId: Id,
});
export type V1WithdrawStudentRequest = z.infer<typeof V1WithdrawStudentRequest>;

export const V1TransferEnrollmentRequest = z.strictObject({
  studentId: Id,
  targetClassroomId: Id,
});
export type V1TransferEnrollmentRequest = z.infer<
  typeof V1TransferEnrollmentRequest
>;

export const V1CreateTermRequest = z.strictObject({
  name: z.string().trim().min(1).max(120),
  startsOn: z.string().date(),
  endsOn: z.string().date(),
});
export type V1CreateTermRequest = z.infer<typeof V1CreateTermRequest>;

// userId is optional: a school admin can seed a roster entry ahead of the
// student's own account existing (students.provisional tracks exactly this)
// and link it later, the same "invite before signup" shape S2's invitations
// established for staff/guardian onboarding.
export const V1CreateStudentRequest = z.strictObject({
  displayName: z.string().trim().min(1).max(160),
  userId: Id.nullable().optional(),
});
export type V1CreateStudentRequest = z.infer<typeof V1CreateStudentRequest>;

export const V1SchoolStudent = z.strictObject({
  id: Id,
  schoolId: Id,
  userId: Id.nullable(),
  studafyId: z.string().min(1),
  displayName: z.string().min(1),
  provisional: z.boolean(),
});
export type V1SchoolStudent = z.infer<typeof V1SchoolStudent>;

import { V1_ROUTE_CATALOGUE } from "@studafy/contracts";

/**
 * AUTH-031 permission catalogue.
 *
 * Permission names are stable API/security vocabulary. Handlers import these
 * values instead of comparing roles themselves. A role is only one input to
 * an authorization decision; tenant and relationship checks remain in the
 * database decision surface shared with DB-021.
 */

export type PermissionScope = "self" | "tenant" | "resource";

export interface PermissionDefinition {
  resource: string;
  scope: PermissionScope;
  /** Resource denials use 404 so an opaque id cannot be used as an oracle. */
  concealDeniedResource: boolean;
  tenantRequired: boolean;
  description: string;
}

export const PERMISSION_CATALOGUE = {
  "account.profile.read": {
    resource: "profile",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Read the authenticated user's profile.",
  },
  "account.context.read": {
    resource: "authorization_context",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Read memberships resolved for the authenticated user.",
  },
  "account.devices.read": {
    resource: "auth_device",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "List the authenticated user's registered devices.",
  },
  "account.device.revoke": {
    resource: "auth_device",
    scope: "self",
    concealDeniedResource: true,
    tenantRequired: false,
    description: "Revoke a device owned by the authenticated user.",
  },
  "account.session.revoke": {
    resource: "auth_session",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Revoke the current or all sessions for the actor.",
  },
  "account.reauth.challenge": {
    resource: "auth_session",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Request a recent-auth challenge for the current session.",
  },
  "account.reauth.verify": {
    resource: "auth_session",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Mint a session-bound, single-use recent-auth grant.",
  },
  "account.identity.link": {
    resource: "auth_identity",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Link a provider identity after recent authentication.",
  },
  "account.identity.unlink": {
    resource: "auth_identity",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Unlink an owned provider identity without orphaning login.",
  },
  "account.deletion.impact": {
    resource: "profile",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Read the server-computed impact of account deletion.",
  },
  "account.deletion.request": {
    resource: "profile",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Request deletion of the authenticated account.",
  },
  "account.deletion.cancel": {
    resource: "profile",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Cancel the authenticated account's pending deletion.",
  },

  // DB-021 read-policy counterparts. These names are accepted by the private
  // decision function and are the declarations future API-041/042 handlers
  // must use when those resources migrate behind /v1.
  "school.read": resource("school", "Read an active member's school."),
  "term.read": resource("term", "Read a term visible under DB-021."),
  "student.read": resource("student", "Read an authorized student record."),
  "guardian_link.read": resource(
    "guardian_link",
    "Read a guardian relationship visible under DB-021.",
  ),
  "classroom.read": resource(
    "classroom",
    "Read a classroom through an exact active relationship.",
  ),
  "classroom_staff.read": resource(
    "classroom_staff",
    "Read classroom staffing through an exact authorized class.",
  ),
  "class_schedule.read": resource(
    "class_schedule",
    "Read a schedule for an authorized classroom.",
  ),
  "lesson_session.read": resource(
    "lesson_session",
    "Read a session subject to staff or filed-state visibility.",
  ),
  "lesson_material.read": resource(
    "lesson_material",
    "Read non-deleted material for a visible lesson session.",
  ),
  "assignment.read": resource(
    "assignment",
    "Read an assignment subject to class and publication state.",
  ),
  "submission.read": resource(
    "submission",
    "Read a submission through the exact class/student relationship.",
  ),
  "assessment.read": resource(
    "assessment",
    "Read an assessment subject to class and publication state.",
  ),
  "assessment_question.read": resource(
    "assessment_question",
    "Read a question; learners are limited to published practice content.",
  ),
  "grade_result.read": resource(
    "grade_result",
    "Read an exact related result; learners see published results only.",
  ),
  "attendance_record.read": resource(
    "attendance_record",
    "Read attendance through the exact class/student relationship.",
  ),
  "wellbeing_event.read": resource(
    "wellbeing_event",
    "Read wellbeing data subject to its visibility classification.",
  ),
  "announcement.read": resource(
    "announcement",
    "Read a published announcement for its exact audience.",
  ),
  "meeting.read": resource(
    "meeting",
    "Read a meeting as creator, staff, or scheduled audience.",
  ),
  "notification.read": resource(
    "notification",
    "Read a notification owned by the authenticated user.",
  ),
  "subscription_entitlement.read": globalResource(
    "subscription_entitlement",
    "Read the authenticated user's legacy subscription entitlement.",
  ),
  "consent_record.read": globalResource(
    "consent_record",
    "Read a policy-consent record owned by the authenticated user.",
  ),
  "practice_session.read": resource(
    "practice_session",
    "Read an authorized practice session.",
  ),
  "resource.read": resource(
    "resource",
    "Read learning content visible through a safe publication.",
  ),
  "resource_version.read": resource(
    "resource_version",
    "Read a visible immutable learning-content version.",
  ),
  "resource_publication.read": resource(
    "resource_publication",
    "Read a safe publication for its exact audience.",
  ),

  // API-041 authoritative academic collections and commands.
  "term.list": resource("school", "List terms in the actor-visible school."),
  "classroom.list": resource(
    "school",
    "List only classrooms related to the actor.",
  ),
  "classroom.create": resource(
    "school",
    "Create a classroom as an active school administrator.",
  ),
  "classroom.update": resource(
    "classroom",
    "Update an exactly assigned classroom.",
  ),
  "classroom.schedule.write": resource(
    "classroom",
    "Replace an exactly assigned classroom schedule.",
  ),
  "classroom.roster.read": resource(
    "classroom",
    "Read an exact classroom roster as staff or admin.",
  ),
  "classroom.staff.read": resource(
    "classroom",
    "Read assigned classroom staff as staff or admin.",
  ),
  "lesson_session.list": resource(
    "school_or_classroom",
    "List relationship-visible lesson sessions.",
  ),
  "resource.list": resource(
    "school_or_classroom",
    "List relationship-visible learning resources.",
  ),
  "resource.create": resource(
    "school",
    "Create text-only content in an assigned classroom.",
  ),
  "resource.revise": resource(
    "resource",
    "Create an immutable revision as assigned staff.",
  ),
  "resource.publish": resource(
    "resource",
    "Publish a safe text resource as assigned staff.",
  ),
  "resource.withdraw": resource(
    "resource",
    "Withdraw a resource publication as assigned staff.",
  ),
  "assignment.list": resource(
    "school_or_classroom",
    "List relationship-visible assignments.",
  ),
  "assignment.create": resource(
    "classroom",
    "Create an assignment in an assigned classroom.",
  ),
  "assignment.publish": resource(
    "assignment",
    "Publish a draft assignment as assigned staff.",
  ),
  "assignment.withdraw": resource(
    "assignment",
    "Withdraw a published assignment as assigned staff.",
  ),
  "assignment.submit": resource(
    "assignment",
    "Submit work as the exact enrolled student.",
  ),
  "submission.list": resource(
    "assignment",
    "List submissions as exact class staff.",
  ),
  "assessment.list": resource(
    "school_or_classroom",
    "List relationship-visible assessments.",
  ),
  "assessment.create": resource(
    "classroom",
    "Create an assessment in an assigned classroom.",
  ),
  "assessment.publish": resource(
    "assessment",
    "Publish an assessment as assigned staff.",
  ),
  "assessment.withdraw": resource(
    "assessment",
    "Withdraw an assessment as assigned staff.",
  ),
  "assessment.submit": resource(
    "assessment",
    "Submit an online assessment as the exact enrolled student.",
  ),
  "assessment_question.list": resource(
    "assessment",
    "Read learner-safe questions for an authorized assessment.",
  ),
  "assessment_question.authoring.list": resource(
    "assessment",
    "Read preferred answers as exact writable class staff.",
  ),
  "assessment_attempt.list": resource(
    "assessment",
    "List assessment attempts as exact class staff.",
  ),
  "grade_result.list": resource(
    "school_class_or_student",
    "List relationship-visible grade results.",
  ),
  "grade_result.review": resource(
    "grade_result",
    "Review a grade as exact class staff.",
  ),
  "grade_result.publish": resource(
    "grade_result",
    "Publish a reviewed grade as exact class staff.",
  ),
  "grade_result.correct": resource(
    "grade_result",
    "Correct a published grade with a reason.",
  ),
  "grade_result.withdraw": resource(
    "grade_result",
    "Withdraw a grade as exact class staff.",
  ),
  "attendance_record.list": resource(
    "school_class_or_student",
    "List relationship-visible attendance.",
  ),
  "attendance_record.write": resource(
    "classroom",
    "Batch-record attendance as exact class staff.",
  ),
  "attendance_roster.read": resource(
    "classroom",
    "Read a dated attendance roster as exact class staff.",
  ),
  "wellbeing_event.list": resource(
    "school_class_or_student",
    "List visibility-filtered wellbeing records.",
  ),
  "wellbeing_event.create": resource(
    "classroom",
    "Create a classified wellbeing record as exact class staff.",
  ),

  // API-042 S1: school provisioning/lifecycle, membership lifecycle,
  // classroom staffing and enrollment transitions.
  "school.provision": {
    resource: "school",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description:
      "Provision a new school as a platform operator. Not client-selectable: the SQL command independently requires a platform_operators row.",
  },
  // Not resource(): its tenantRequired: true default needs a membership-
  // derived tenant, which a platform operator - one of this permission's two
  // legitimate actors - never has. private.authz_authorize's own
  // is_platform_operator() OR is_school_admin() check is the real guard,
  // the same reasoning support_access.* and guardian_link.revoke already
  // document for the identical gap.
  "school.suspend": {
    resource: "school",
    scope: "resource",
    concealDeniedResource: true,
    tenantRequired: false,
    description: "Suspend a school as its administrator or a platform operator.",
  },
  "school.close": {
    resource: "school",
    scope: "resource",
    concealDeniedResource: true,
    tenantRequired: false,
    description: "Close a school as its administrator or a platform operator.",
  },
  "membership.grant": resource(
    "school",
    "Grant a school membership as an active school administrator.",
  ),
  "membership.activate": resource(
    "membership",
    "Reactivate a suspended membership as an active administrator in its school.",
  ),
  "membership.suspend": resource(
    "membership",
    "Suspend a membership as an active administrator in its school.",
  ),
  "membership.revoke": resource(
    "membership",
    "Revoke a membership as an active administrator in its school.",
  ),
  "classroom_staff.write": resource(
    "classroom",
    "Assign or remove classroom staff as school admin or the classroom's lead teacher.",
  ),
  "enrollment.write": resource(
    "classroom",
    "Enroll, withdraw or transfer a student as school admin or exact class writer.",
  ),

  // API-042 S2: invitations.
  "invitation.issue": resource(
    "school",
    "Issue a hashed, expiring, attempt-budgeted invitation as a school administrator.",
  ),
  "invitation.list": resource(
    "school",
    "List invitations as a school administrator.",
  ),
  "invitation.revoke": resource(
    "invitation",
    "Revoke a pending invitation as its issuing school's administrator.",
  ),
  "invitation.accept": {
    resource: "invitation",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description:
      "Accept an invitation by presenting its valid token. The token is the credential; no resourceId is resolved.",
  },

  // API-042 S3: guarded student locator and guardian linking.
  "student.locate": {
    resource: "student_locate",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description:
      "Look up one student by its opaque studafyId. Rate-limited and audited per attempt; response shape is uniform whether found or not.",
  },
  "guardian_link.request": {
    resource: "guardian_link",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description:
      "Request a guardian link to a student as the authenticated actor. Starts pending; a school administrator must verify it.",
  },
  "conversation.list": {
    resource: "conversation",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "List conversations the authenticated actor actively participates in, across every school.",
  },
  "conversation.create": {
    resource: "conversation",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Create a conversation as a member or verified guardian of the named school.",
  },
  // Not tenantRequired for the same reason as guardian_link.revoke: a
  // verified-guardian participant frequently has no memberships row at all.
  // is_conversation_participant(conversationId) is the real guard.
  "message.list": {
    resource: "conversation",
    scope: "resource",
    concealDeniedResource: true,
    tenantRequired: false,
    description: "List messages in a conversation the actor actively participates in.",
  },
  "message.send": {
    resource: "conversation",
    scope: "resource",
    concealDeniedResource: true,
    tenantRequired: false,
    description: "Send a message in a conversation the actor actively participates in.",
  },
  "announcement.create": resource(
    "school_or_classroom",
    "Create an announcement as a school administrator (school-wide) or the classroom's exact writer.",
  ),
  "announcement.list": resource(
    "school",
    "List announcements visible to an active member, filtered per row by classroom relationship.",
  ),

  // API-042 S5: meetings.
  "meeting.request": resource(
    "classroom",
    "Request a meeting as the classroom's exact writer.",
  ),
  "meeting.cancel": resource(
    "meeting",
    "Cancel a meeting as its school administrator or the classroom's exact writer.",
  ),
  // Not tenantRequired for the same reason as message.list/message.send: an
  // invited guardian recipient may have no memberships row at all.
  // is_meeting_authorized(...) or an exact meeting_deliveries row is the
  // real guard.
  // API-042 S6: notifications. All self-scoped - every operation reads or
  // writes only the authenticated actor's own rows, across every school.
  "notification.list": {
    resource: "notification",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "List or count the authenticated actor's own in-app notifications.",
  },
  "notification.mark_read": {
    resource: "notification",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Mark the authenticated actor's own notifications read, bounded to 100 ids or all.",
  },
  "notification.preferences.read": {
    resource: "notification_preference",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Read the authenticated actor's own notification channel/category preferences.",
  },
  "notification.preferences.write": {
    resource: "notification_preference",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Set one of the authenticated actor's own notification channel/category preferences.",
  },

  // API-042 S7: profile correction and data export request/status.
  // account.deletion.* (AUTH-030/031) already covers deletion; this is the
  // other half of account rights under the same self scope.
  "account.profile.write": {
    resource: "profile",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Update the authenticated actor's own allowlisted profile fields.",
  },
  "account.export.request": {
    resource: "data_export_request",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Request an export of the authenticated actor's own data.",
  },
  "account.export.status": {
    resource: "data_export_request",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Read the status of the authenticated actor's own most recent data export request.",
  },

  // API-042 S8: time-bounded, MFA-gated, two-person-approved support
  // access. Requesting has no existing resource to resolve a tenant from
  // (self-scoped, like provisionSchool); the SQL command's own
  // is_platform_operator() check is the real guard. Every other operation
  // is not tenantRequired for the same reason S1's platform-operator
  // widening exists: an operator approving/starting/revoking access to a
  // school they are not a member of must not be blocked by the
  // membership-only tenant cache before the real check ever runs.
  "support_access.request": {
    resource: "support_access_grant",
    scope: "self",
    concealDeniedResource: false,
    tenantRequired: false,
    description: "Request a time-bounded support session as a platform operator, with MFA and a ticket reference.",
  },
  "support_access.approve": {
    resource: "support_access_grant",
    scope: "resource",
    concealDeniedResource: true,
    tenantRequired: false,
    description: "Approve a pending support-access request as a different platform operator, with MFA.",
  },
  "support_access.start": {
    resource: "support_access_grant",
    scope: "resource",
    concealDeniedResource: true,
    tenantRequired: false,
    description: "Start an approved support session as its exact original requester.",
  },
  "support_access.revoke": {
    resource: "support_access_grant",
    scope: "resource",
    concealDeniedResource: true,
    tenantRequired: false,
    description: "Revoke a support-access grant as a platform operator or the affected school's administrator.",
  },
  "support_access.list": resource(
    "school",
    "List support-access grants for a school as a platform operator or that school's administrator.",
  ),
  "meeting.status": {
    resource: "meeting",
    scope: "resource",
    concealDeniedResource: true,
    tenantRequired: false,
    description: "Read meeting and delivery status as staff or an invited recipient.",
  },
  "guardian_link.verify": resource(
    "guardian_link",
    "Verify a pending guardian link as the student's school administrator.",
  ),
  // Not tenantRequired: an admin revoking always has a membership in the
  // resolved school and gets the usual tenant context, but the linked
  // guardian revoking their own link often has no memberships row at all -
  // guardian membership is "if required by school policy" per
  // instructions.md section 6, not universal, and a guardian_links row is
  // not a membership. The SQL command's own
  // is_school_admin(tenant) or guardian_id = auth.uid() check is the real
  // guard either way; this only stops the tenant-cache lookup from denying
  // a guardian who has no membership row before that check ever runs.
  "guardian_link.revoke": {
    resource: "guardian_link",
    scope: "resource",
    concealDeniedResource: true,
    tenantRequired: false,
    description:
      "Revoke a guardian link as the student's school administrator or the linked guardian themselves.",
  },
} as const satisfies Record<string, PermissionDefinition>;

function resource(resourceName: string, description: string) {
  return {
    resource: resourceName,
    scope: "resource",
    concealDeniedResource: true,
    tenantRequired: true,
    description,
  } as const;
}

function globalResource(resourceName: string, description: string) {
  return {
    resource: resourceName,
    scope: "resource",
    concealDeniedResource: true,
    tenantRequired: false,
    description,
  } as const;
}

export type Permission = keyof typeof PERMISSION_CATALOGUE;

export const PERMISSIONS = Object.freeze(
  Object.keys(PERMISSION_CATALOGUE) as Permission[],
);

export function isPermission(value: string): value is Permission {
  return Object.hasOwn(PERMISSION_CATALOGUE, value);
}

export interface ProtectedHandlerDeclaration {
  method: "GET" | "POST" | "PUT" | "PATCH" | "DELETE";
  path: string;
  permission: Permission;
}

/**
 * Inventory of the protected handlers shipped in AUTH-030/031.
 *
 * The route coverage test compares this list to the actual route table and
 * makes both missing declarations and stale declarations release failures.
 */
export const AUTH_HANDLER_PERMISSIONS = Object.freeze(
  [
    { method: "GET", path: "/v1/me", permission: "account.profile.read" },
    {
      method: "GET",
      path: "/v1/auth/context",
      permission: "account.context.read",
    },
    {
      method: "GET",
      path: "/v1/auth/devices",
      permission: "account.devices.read",
    },
    {
      method: "POST",
      path: "/v1/auth/devices/revoke",
      permission: "account.device.revoke",
    },
    {
      method: "POST",
      path: "/v1/auth/sign-out",
      permission: "account.session.revoke",
    },
    {
      method: "POST",
      path: "/v1/auth/reauth/challenge",
      permission: "account.reauth.challenge",
    },
    {
      method: "POST",
      path: "/v1/auth/reauth/verify",
      permission: "account.reauth.verify",
    },
    {
      method: "POST",
      path: "/v1/auth/identities/link",
      permission: "account.identity.link",
    },
    {
      method: "POST",
      path: "/v1/auth/identities/unlink",
      permission: "account.identity.unlink",
    },
    {
      method: "GET",
      path: "/v1/account/deletion-impact",
      permission: "account.deletion.impact",
    },
    {
      method: "POST",
      path: "/v1/account/deletion-request",
      permission: "account.deletion.request",
    },
    {
      method: "POST",
      path: "/v1/account/deletion-cancel",
      permission: "account.deletion.cancel",
    },
    ...V1_ROUTE_CATALOGUE.slice(12).map((route) => ({
      method: route.method.toUpperCase() as "GET" | "POST",
      path: route.path.replaceAll(/\{([^}]+)\}/g, ":$1"),
      permission: route.permission as Permission,
    })),
  ] satisfies ProtectedHandlerDeclaration[],
);

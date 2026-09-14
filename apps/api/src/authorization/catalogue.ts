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

  // Reserved for the bounded API-042 membership commands. They are catalogued
  // now so no future handler invents a role check outside this service.
  "membership.grant": resource(
    "school",
    "Grant a school membership as an active school administrator.",
  ),
  "membership.revoke": resource(
    "membership",
    "Revoke a membership as an active administrator in its school.",
  ),
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
  ] satisfies ProtectedHandlerDeclaration[],
);

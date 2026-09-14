import type { z } from "zod";
import {
  V1AuthContextResponse,
  V1AuthDeviceListResponse,
  V1AuthDeviceRevokeRequest,
  V1AuthDeviceRevokeResponse,
  V1AuthSignOutRequest,
  V1AuthSignOutResponse,
  V1DeletionCancelRequest,
  V1DeletionCancelResponse,
  V1DeletionImpactResponse,
  V1DeletionRequestRequest,
  V1DeletionRequestResponse,
  V1IdentityLinkRequest,
  V1IdentityLinkResponse,
  V1IdentityUnlinkRequest,
  V1IdentityUnlinkResponse,
  V1ReauthChallengeRequest,
  V1ReauthChallengeResponse,
  V1ReauthVerifyRequest,
  V1ReauthVerifyResponse,
} from "./auth";
import { V1MeResponse } from "./me";
import type { IdempotencyMode } from "./platform";

export interface V1RouteContract {
  method: "get" | "post";
  path: string;
  operationId: string;
  summary: string;
  permission: string;
  idempotency: IdempotencyMode;
  request?: z.ZodType;
  requestSchema?: string;
  response: z.ZodType;
  responseSchema: string;
}

/** Canonical inventory for every implemented /v1 handler. */
export const V1_ROUTE_CATALOGUE = [
  {
    method: "get",
    path: "/v1/me",
    operationId: "getMe",
    summary: "Authenticated profile and tenant memberships",
    permission: "account.profile.read",
    idempotency: "none",
    response: V1MeResponse,
    responseSchema: "V1MeResponse",
  },
  {
    method: "get",
    path: "/v1/auth/context",
    operationId: "getAuthContext",
    summary: "Server-derived tenant and role context",
    permission: "account.context.read",
    idempotency: "none",
    response: V1AuthContextResponse,
    responseSchema: "V1AuthContextResponse",
  },
  {
    method: "get",
    path: "/v1/auth/devices",
    operationId: "listAuthDevices",
    summary: "Devices that have held a session for this account",
    permission: "account.devices.read",
    idempotency: "none",
    response: V1AuthDeviceListResponse,
    responseSchema: "V1AuthDeviceListResponse",
  },
  {
    method: "post",
    path: "/v1/auth/devices/revoke",
    operationId: "revokeAuthDevice",
    summary: "Revoke one owned device",
    permission: "account.device.revoke",
    idempotency: "required",
    request: V1AuthDeviceRevokeRequest,
    requestSchema: "V1AuthDeviceRevokeRequest",
    response: V1AuthDeviceRevokeResponse,
    responseSchema: "V1AuthDeviceRevokeResponse",
  },
  {
    method: "post",
    path: "/v1/auth/sign-out",
    operationId: "signOut",
    summary: "Revoke the current or every session",
    permission: "account.session.revoke",
    idempotency: "required",
    request: V1AuthSignOutRequest,
    requestSchema: "V1AuthSignOutRequest",
    response: V1AuthSignOutResponse,
    responseSchema: "V1AuthSignOutResponse",
  },
  {
    method: "post",
    path: "/v1/auth/reauth/challenge",
    operationId: "challengeReauth",
    summary: "Describe the assurance required for a privileged action",
    permission: "account.reauth.challenge",
    idempotency: "required",
    request: V1ReauthChallengeRequest,
    requestSchema: "V1ReauthChallengeRequest",
    response: V1ReauthChallengeResponse,
    responseSchema: "V1ReauthChallengeResponse",
  },
  {
    method: "post",
    path: "/v1/auth/reauth/verify",
    operationId: "verifyReauth",
    summary: "Issue a single-use recent-authentication grant",
    permission: "account.reauth.verify",
    idempotency: "forbidden",
    request: V1ReauthVerifyRequest,
    requestSchema: "V1ReauthVerifyRequest",
    response: V1ReauthVerifyResponse,
    responseSchema: "V1ReauthVerifyResponse",
  },
  {
    method: "post",
    path: "/v1/auth/identities/link",
    operationId: "linkIdentity",
    summary: "Link a verified sign-in identity",
    permission: "account.identity.link",
    idempotency: "required",
    request: V1IdentityLinkRequest,
    requestSchema: "V1IdentityLinkRequest",
    response: V1IdentityLinkResponse,
    responseSchema: "V1IdentityLinkResponse",
  },
  {
    method: "post",
    path: "/v1/auth/identities/unlink",
    operationId: "unlinkIdentity",
    summary: "Unlink a sign-in identity",
    permission: "account.identity.unlink",
    idempotency: "required",
    request: V1IdentityUnlinkRequest,
    requestSchema: "V1IdentityUnlinkRequest",
    response: V1IdentityUnlinkResponse,
    responseSchema: "V1IdentityUnlinkResponse",
  },
  {
    method: "get",
    path: "/v1/account/deletion-impact",
    operationId: "getDeletionImpact",
    summary: "Preview the effect of account deletion",
    permission: "account.deletion.impact",
    idempotency: "none",
    response: V1DeletionImpactResponse,
    responseSchema: "V1DeletionImpactResponse",
  },
  {
    method: "post",
    path: "/v1/account/deletion-request",
    operationId: "requestAccountDeletion",
    summary: "Schedule account deletion",
    permission: "account.deletion.request",
    idempotency: "required",
    request: V1DeletionRequestRequest,
    requestSchema: "V1DeletionRequestRequest",
    response: V1DeletionRequestResponse,
    responseSchema: "V1DeletionRequestResponse",
  },
  {
    method: "post",
    path: "/v1/account/deletion-cancel",
    operationId: "cancelAccountDeletion",
    summary: "Cancel a pending account deletion",
    permission: "account.deletion.cancel",
    idempotency: "required",
    request: V1DeletionCancelRequest,
    requestSchema: "V1DeletionCancelRequest",
    response: V1DeletionCancelResponse,
    responseSchema: "V1DeletionCancelResponse",
  },
] as const satisfies readonly V1RouteContract[];

export type V1OperationId = (typeof V1_ROUTE_CATALOGUE)[number]["operationId"];

export function v1Route(
  operationId: V1OperationId,
): (typeof V1_ROUTE_CATALOGUE)[number] {
  const route = V1_ROUTE_CATALOGUE.find((entry) =>
    entry.operationId === operationId
  );
  if (!route) throw new Error(`Unknown v1 operation: ${operationId}`);
  return route;
}

/**
 * In-memory stand-in for the database surface, so route and middleware
 * behaviour can be tested without Postgres.
 *
 * It mirrors the semantics the SQL functions enforce — actor scoping,
 * single-use grants, the revocation watermark — because those semantics are
 * what the route tests assert. The SQL itself is proven separately by
 * supabase/tests/auth030_access.sql and by repository.integration.test.ts.
 */
import type {
  AuthContextRepository,
  SessionContext,
} from "../../src/auth/context";

export interface FakeUser {
  context: SessionContext;
}

interface Grant {
  purpose: string;
  grantHash: string;
  sessionId: string;
  consumed: boolean;
  expiresAt: number;
}

export interface RecordedEvent {
  subject: string | null;
  eventType: string;
  outcome: string;
  reasonCode: string;
}

export function baseContext(
  overrides: Partial<SessionContext> = {},
): SessionContext {
  return {
    userId: "11111111-2222-4333-8444-555555555555",
    displayName: "Rana Haddad",
    locale: "en",
    profileStatus: "active",
    profileDeletedAt: null,
    revokedBefore: null,
    deletionState: null,
    memberships: [
      {
        id: "aaaaaaaa-0000-4000-8000-000000000001",
        school_id: "bbbbbbbb-0000-4000-8000-000000000001",
        school_name: "Al-Noor International",
        school_timezone: "Asia/Riyadh",
        role: "teacher",
        active: true,
        active_term_id: "cccccccc-0000-4000-8000-000000000001",
      },
    ],
    membershipVersion: "v1",
    mfaEnrolled: false,
    ...overrides,
  };
}

export class FakeAuthRepository {
  contexts = new Map<string, SessionContext>();
  devices = new Map<string, {
    id: string;
    user: string;
    platform: "ios" | "android" | "other";
    app_version: string | null;
    display_label: string | null;
    first_seen_at: string;
    last_seen_at: string;
    revoked_at: string | null;
  }>();
  grants: Grant[] = [];
  identities = new Map<string, string>();
  deletions = new Map<
    string,
    { id: string; state: string; execute_after: string }
  >();
  events: RecordedEvent[] = [];
  /** Set to fail every security-event write, to prove denials still answer. */
  failEventWrites = false;

  load(subject: string): Promise<SessionContext | null> {
    return Promise.resolve(this.contexts.get(subject) ?? null);
  }

  listDevices(subject: string) {
    return Promise.resolve(
      [...this.devices.values()]
        .filter((device) => device.user === subject)
        .map(({ user: _user, ...rest }) => rest),
    );
  }

  touchDevice(): Promise<{ id: string; revoked: boolean } | null> {
    return Promise.resolve({ id: "device-1", revoked: false });
  }

  revokeDevice(subject: string, deviceId: string): Promise<boolean> {
    const device = this.devices.get(deviceId);
    // Ownership is enforced here exactly as the SQL enforces it.
    if (!device || device.user !== subject || device.revoked_at) {
      return Promise.resolve(false);
    }
    device.revoked_at = new Date().toISOString();
    return Promise.resolve(true);
  }

  signOutAll(subject: string): Promise<string | null> {
    const watermark = new Date().toISOString();
    const context = this.contexts.get(subject);
    if (context) context.revokedBefore = watermark;
    for (const device of this.devices.values()) {
      if (device.user === subject) device.revoked_at = watermark;
    }
    return Promise.resolve(watermark);
  }

  issueReauthGrant(
    subject: string,
    grant: {
      purpose: string;
      grantHash: string;
      sessionId: string;
      ttlSeconds: number;
    },
  ): Promise<string | null> {
    // Replaces any live grant for the same purpose, as the SQL does.
    this.grants = this.grants.filter((existing) =>
      !(existing.purpose === grant.purpose && !existing.consumed &&
        existing.sessionId === grant.sessionId)
    );
    const expiresAt = Date.now() + grant.ttlSeconds * 1000;
    this.grants.push({
      purpose: grant.purpose,
      grantHash: grant.grantHash,
      sessionId: grant.sessionId,
      consumed: false,
      expiresAt,
    });
    void subject;
    return Promise.resolve(new Date(expiresAt).toISOString());
  }

  consumeReauthGrant(
    _subject: string,
    grant: { purpose: string; grantHash: string; sessionId: string },
  ): Promise<boolean> {
    const match = this.grants.find((existing) =>
      existing.purpose === grant.purpose &&
      existing.grantHash === grant.grantHash &&
      existing.sessionId === grant.sessionId &&
      !existing.consumed &&
      existing.expiresAt > Date.now()
    );
    if (!match) return Promise.resolve(false);
    match.consumed = true;
    return Promise.resolve(true);
  }

  linkIdentity(
    subject: string,
    provider: string,
    providerSubject: string,
  ): Promise<string> {
    const key = `${provider}:${providerSubject}`;
    const owner = this.identities.get(key);
    if (owner === subject) return Promise.resolve("already_linked");
    if (owner) return Promise.resolve("collision");
    this.identities.set(key, subject);
    return Promise.resolve("linked");
  }

  unlinkIdentity(
    subject: string,
    provider: string,
    providerSubject: string,
  ): Promise<string> {
    const key = `${provider}:${providerSubject}`;
    if (this.identities.get(key) !== subject) {
      return Promise.resolve("not_linked");
    }
    const owned = [...this.identities.values()].filter((value) =>
      value === subject
    );
    if (owned.length <= 1) return Promise.resolve("last_identity");
    this.identities.delete(key);
    return Promise.resolve("unlinked");
  }

  deletionImpact(): Promise<Record<string, unknown>> {
    return Promise.resolve({
      memberships: [{ school_name: "Al-Noor International", role: "teacher" }],
      retained_school_records: {
        attendance: 12,
        grades: 4,
        submissions: 9,
        wellbeing: 0,
      },
      deleted_personal_data: {
        profile: 1,
        devices: 2,
        consents: 1,
        notifications: 7,
      },
      guardian_links: 0,
      active_entitlements: 0,
    });
  }

  requestDeletion(
    subject: string,
    _reason: string,
    _impact: unknown,
    days: number,
  ) {
    const existing = this.deletions.get(subject);
    if (existing && existing.state === "grace_period") {
      return Promise.resolve({ ...existing, created: false });
    }
    const record = {
      id: "deletion-1",
      state: "grace_period",
      execute_after: new Date(Date.now() + days * 86_400_000).toISOString(),
    };
    this.deletions.set(subject, record);
    return Promise.resolve({ ...record, created: true });
  }

  cancelDeletion(subject: string): Promise<boolean> {
    const existing = this.deletions.get(subject);
    if (!existing || existing.state !== "grace_period") {
      return Promise.resolve(false);
    }
    existing.state = "cancelled";
    return Promise.resolve(true);
  }

  recordEvent(event: {
    subject: string | null;
    eventType: string;
    outcome: string;
    reasonCode: string;
  }): Promise<void> {
    if (this.failEventWrites) {
      return Promise.reject(new Error("audit sink unavailable"));
    }
    this.events.push({
      subject: event.subject,
      eventType: event.eventType,
      outcome: event.outcome,
      reasonCode: event.reasonCode,
    });
    return Promise.resolve();
  }

  asRepository(): AuthContextRepository {
    return this as unknown as AuthContextRepository;
  }
}

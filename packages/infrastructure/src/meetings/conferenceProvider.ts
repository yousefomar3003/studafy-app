/**
 * DL-052 conferencing provider port and its Google Calendar adapter. The
 * worker creates one calendar event per meeting, with a Meet link, invites
 * the attendees, and withdraws the event when the meeting is cancelled.
 *
 * Calls are idempotent: the event id is derived from the meeting id, so a
 * retry after a lost response finds the event it already created instead of
 * inviting everyone twice.
 */
import { google } from "googleapis";
import { JWT } from "google-auth-library";

export interface ConferenceScheduleInput {
  meetingId: string;
  title: string;
  startsAt: string;
  endsAt: string;
  attendees: readonly string[];
}

export interface ScheduledConference {
  eventId: string;
  joinUrl: string | null;
}

export interface ConferenceProvider {
  schedule(input: ConferenceScheduleInput): Promise<ScheduledConference>;
  cancel(eventId: string): Promise<void>;
}

/** `terminal` means retrying cannot help (a refusal, not an outage). */
export class ConferenceProviderError extends Error {
  constructor(readonly code: string, readonly terminal: boolean) {
    super(code);
    this.name = "ConferenceProviderError";
  }
}

export interface GoogleCalendarConfig {
  serviceAccountJson: string;
  /** The Workspace user the service account acts for (domain-wide delegation). */
  organizerEmail: string;
}

/** Google Calendar event ids allow only base32hex characters (a-v, 0-9). */
export function calendarEventIdFor(meetingId: string): string {
  return `m${meetingId.toLowerCase().replaceAll("-", "")}`;
}

function statusOf(error: unknown): number | null {
  const candidate = error as {
    code?: unknown;
    response?: { status?: unknown };
  };
  const status = candidate?.response?.status ?? candidate?.code;
  return typeof status === "number" ? status : null;
}

function classify(error: unknown): ConferenceProviderError {
  const status = statusOf(error);
  if (status === null) {
    return new ConferenceProviderError("PROVIDER_UNREACHABLE", false);
  }
  if (status === 429 || status >= 500) {
    return new ConferenceProviderError("PROVIDER_UNAVAILABLE", false);
  }
  if (status === 401) {
    return new ConferenceProviderError("PROVIDER_AUTH_FAILED", false);
  }
  return new ConferenceProviderError(`PROVIDER_REFUSED_${status}`, true);
}

export class GoogleCalendarConferenceProvider implements ConferenceProvider {
  readonly #auth: JWT;

  constructor(config: GoogleCalendarConfig) {
    let credentials: { client_email?: string; private_key?: string };
    try {
      credentials = JSON.parse(config.serviceAccountJson);
    } catch {
      throw new ConferenceProviderError("PROVIDER_CONFIG_INVALID", true);
    }
    if (!credentials.client_email || !credentials.private_key) {
      throw new ConferenceProviderError("PROVIDER_CONFIG_INVALID", true);
    }
    this.#auth = new JWT({
      email: credentials.client_email,
      key: credentials.private_key,
      scopes: ["https://www.googleapis.com/auth/calendar.events"],
      subject: config.organizerEmail,
    });
  }

  #calendar() {
    return google.calendar({ version: "v3", auth: this.#auth as never });
  }

  async schedule(input: ConferenceScheduleInput): Promise<ScheduledConference> {
    const eventId = calendarEventIdFor(input.meetingId);
    const calendar = this.#calendar();
    try {
      const created = await calendar.events.insert({
        calendarId: "primary",
        conferenceDataVersion: 1,
        sendUpdates: "all",
        requestBody: {
          id: eventId,
          summary: input.title,
          start: { dateTime: input.startsAt },
          end: { dateTime: input.endsAt },
          attendees: input.attendees.map((email) => ({ email })),
          // Attendees see each other only if the school wants that; the
          // default keeps the guest list private.
          guestsCanSeeOtherGuests: false,
          conferenceData: {
            createRequest: {
              requestId: input.meetingId,
              conferenceSolutionKey: { type: "hangoutsMeet" },
            },
          },
        },
      });
      return { eventId, joinUrl: created.data.hangoutLink ?? null };
    } catch (error) {
      // 409: this meeting's event already exists from an earlier attempt.
      if (statusOf(error) === 409) {
        try {
          const existing = await calendar.events.get({
            calendarId: "primary",
            eventId,
          });
          return { eventId, joinUrl: existing.data.hangoutLink ?? null };
        } catch (inner) {
          throw classify(inner);
        }
      }
      throw classify(error);
    }
  }

  async cancel(eventId: string): Promise<void> {
    try {
      await this.#calendar().events.delete({
        calendarId: "primary",
        eventId,
        sendUpdates: "all",
      });
    } catch (error) {
      const status = statusOf(error);
      if (status === 404 || status === 410) return;
      throw classify(error);
    }
  }
}

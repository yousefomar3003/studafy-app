/**
 * DL-053 email and push senders. Provider endpoints are constants, never
 * configuration: a changed environment variable must not be able to
 * redirect notification traffic somewhere else (the SEC-001 study-coach
 * lesson). Only fixed, content-free copy is sent.
 */
import { GoogleAuth } from "google-auth-library";

/** `terminal`: retrying cannot help. `invalidTarget`: drop that address/token. */
export class ChannelSendError extends Error {
  constructor(
    readonly code: string,
    readonly terminal: boolean,
    readonly invalidTarget = false,
    /** The provider's own short reason (e.g. FCM's THIRD_PARTY_AUTH_ERROR),
     * for diagnosis only; never a token, address or message text. */
    readonly detail: string | null = null,
  ) {
    super(code);
    this.name = "ChannelSendError";
  }
}

export interface EmailMessage {
  to: string;
  subject: string;
  text: string;
}

export interface EmailSender {
  send(message: EmailMessage): Promise<{ providerMessageId: string | null }>;
}

export interface PushMessage {
  token: string;
  title: string;
  body: string;
  /**
   * Opaque routing hints for the app (a template key, the in-app
   * notification's id); never content.
   */
  data: Record<string, string>;
}

export interface PushSender {
  send(message: PushMessage): Promise<{ providerMessageId: string | null }>;
}

function classifyHttp(status: number): ChannelSendError {
  if (status === 429 || status >= 500) {
    return new ChannelSendError(`PROVIDER_UNAVAILABLE_${status}`, false);
  }
  if (status === 401 || status === 403) {
    return new ChannelSendError(`PROVIDER_AUTH_${status}`, false);
  }
  return new ChannelSendError(`PROVIDER_REFUSED_${status}`, true);
}

/**
 * FCM's reason for a refusal, from its error body: the `errorCode` of its
 * FcmError detail (THIRD_PARTY_AUTH_ERROR means APNs refused the app's key;
 * SENDER_ID_MISMATCH a token from another Firebase project), else the
 * error status. Only an upper-case code is kept; nothing else of the body.
 */
export function fcmReason(body: unknown): string | null {
  const error = (body as { error?: Record<string, unknown> } | null)?.error;
  if (!error) return null;
  const details = Array.isArray(error["details"]) ? error["details"] : [];
  const codes = [
    ...details.map((d) => (d as Record<string, unknown>)?.["errorCode"]),
    error["status"],
  ];
  const code = codes.find((c) =>
    typeof c === "string" && /^[A-Z][A-Z0-9_]{1,59}$/.test(c)
  );
  return typeof code === "string" ? code : null;
}

const RESEND_ENDPOINT = "https://api.resend.com/emails";

export interface ResendConfig {
  apiKey: string;
  from: string;
  fetchImpl?: typeof fetch;
}

/** Resend's HTTP API. Swapping providers means another adapter, not a URL. */
export class ResendEmailSender implements EmailSender {
  readonly #config: ResendConfig;

  constructor(config: ResendConfig) {
    this.#config = config;
  }

  async send(message: EmailMessage) {
    const fetchImpl = this.#config.fetchImpl ?? fetch;
    let response: Response;
    try {
      response = await fetchImpl(RESEND_ENDPOINT, {
        method: "POST",
        redirect: "error",
        signal: AbortSignal.timeout(10_000),
        headers: {
          authorization: `Bearer ${this.#config.apiKey}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          from: this.#config.from,
          to: [message.to],
          subject: message.subject,
          text: message.text,
        }),
      });
    } catch {
      throw new ChannelSendError("PROVIDER_UNREACHABLE", false);
    }
    if (response.status === 422) {
      throw new ChannelSendError("EMAIL_ADDRESS_REJECTED", true, true);
    }
    if (!response.ok) throw classifyHttp(response.status);
    const body = await response.json().catch(() => ({})) as { id?: unknown };
    return {
      providerMessageId: typeof body.id === "string" ? body.id : null,
    };
  }
}

/**
 * The Android notification channel every push is posted to. The app creates
 * it at start-up (MainActivity.kt) and names it as Firebase's default in the
 * manifest; naming it on the message too keeps a push off Android's
 * "Miscellaneous" fallback channel.
 */
export const ANDROID_NOTIFICATION_CHANNEL_ID = "studafy_notifications";

export interface FcmConfig {
  projectId: string;
  serviceAccountJson: string;
  fetchImpl?: typeof fetch;
  /** Tests only: stands in for the service account's OAuth token. */
  accessToken?: () => Promise<string | null | undefined>;
}

/** Firebase Cloud Messaging HTTP v1; it also delivers to iOS through APNs. */
export class FcmPushSender implements PushSender {
  readonly #auth: GoogleAuth;
  readonly #endpoint: string;
  readonly #fetch: typeof fetch;
  readonly #accessToken: () => Promise<string | null | undefined>;

  constructor(config: FcmConfig) {
    if (!/^[a-z][a-z0-9-]{4,29}$/.test(config.projectId)) {
      throw new ChannelSendError("PROVIDER_CONFIG_INVALID", true);
    }
    let credentials: Record<string, unknown>;
    try {
      credentials = JSON.parse(config.serviceAccountJson);
    } catch {
      throw new ChannelSendError("PROVIDER_CONFIG_INVALID", true);
    }
    this.#auth = new GoogleAuth({
      credentials,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    this.#endpoint =
      `https://fcm.googleapis.com/v1/projects/${config.projectId}/messages:send`;
    this.#fetch = config.fetchImpl ?? fetch;
    this.#accessToken = config.accessToken ??
      (() => this.#auth.getAccessToken());
  }

  async send(message: PushMessage) {
    let token: string | null | undefined;
    try {
      token = await this.#accessToken();
    } catch {
      throw new ChannelSendError("PROVIDER_AUTH_FAILED", false);
    }
    let response: Response;
    try {
      response = await this.#fetch(this.#endpoint, {
        method: "POST",
        redirect: "error",
        signal: AbortSignal.timeout(10_000),
        headers: {
          authorization: `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: message.token,
            notification: { title: message.title, body: message.body },
            data: message.data,
            android: {
              notification: { channel_id: ANDROID_NOTIFICATION_CHANNEL_ID },
            },
          },
        }),
      });
    } catch {
      throw new ChannelSendError("PROVIDER_UNREACHABLE", false);
    }
    if (response.status === 404) {
      // FCM's UNREGISTERED: the app was uninstalled or the token rotated.
      throw new ChannelSendError("UNREGISTERED", true, true);
    }
    if (!response.ok) {
      const refused = classifyHttp(response.status);
      throw new ChannelSendError(
        refused.code,
        refused.terminal,
        refused.invalidTarget,
        fcmReason(await response.json().catch(() => null)),
      );
    }
    const body = await response.json().catch(() => ({})) as {
      name?: unknown;
    };
    return {
      providerMessageId: typeof body.name === "string" ? body.name : null,
    };
  }
}

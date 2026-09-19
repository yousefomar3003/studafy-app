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
  /** Opaque routing hints for the app (a template key); never content. */
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

export interface FcmConfig {
  projectId: string;
  serviceAccountJson: string;
  fetchImpl?: typeof fetch;
}

/** Firebase Cloud Messaging HTTP v1; it also delivers to iOS through APNs. */
export class FcmPushSender implements PushSender {
  readonly #auth: GoogleAuth;
  readonly #endpoint: string;
  readonly #fetch: typeof fetch;

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
  }

  async send(message: PushMessage) {
    let token: string | null | undefined;
    try {
      token = await this.#auth.getAccessToken();
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
    if (!response.ok) throw classifyHttp(response.status);
    const body = await response.json().catch(() => ({})) as {
      name?: unknown;
    };
    return {
      providerMessageId: typeof body.name === "string" ? body.name : null,
    };
  }
}

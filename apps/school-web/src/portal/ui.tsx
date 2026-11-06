import { type ReactNode, useEffect, useRef, useState } from "react";
import { portalConfig } from "./config";
import { errorText, useCopy } from "./i18n";
import type { Loaded } from "./load";

/** A page of the legal site, in the portal's language. */
export function legalUrl(
  lang: "en" | "ar",
  page: "terms" | "privacy" | "school-agreement",
): string {
  return `https://legal.studafy.com${lang === "ar" ? "/ar" : ""}/${page}`;
}

/** "I accept the Studafy School Agreement", with the agreement a tap away. */
export function AgreementCheck({ checked, onChange }: {
  checked: boolean;
  onChange: (checked: boolean) => void;
}) {
  const copy = useCopy();
  return (
    <label className="check">
      <input
        type="checkbox"
        checked={checked}
        onChange={(e) => onChange(e.target.checked)}
      />
      <span>
        {copy.agreement.before}
        <a
          href={legalUrl(copy.lang, "school-agreement")}
          target="_blank"
          rel="noopener noreferrer"
        >
          {copy.agreement.link}
        </a>
        {copy.agreement.after}
      </span>
    </label>
  );
}

/** Loading, a refusal with Try again, or the content. */
export function Loader<T>(
  { value, children, onRetry }: {
    value: Loaded<T>;
    onRetry: () => void;
    children: (data: T) => ReactNode;
  },
) {
  const copy = useCopy();
  if (value.state === "loading") {
    return <p className="state" role="status">{copy.loading}</p>;
  }
  if (value.state === "error") {
    return (
      <div className="state error" role="alert">
        <p>{errorText(copy, value.code)}</p>
        <button type="button" className="btn ghost" onClick={onRetry}>
          {copy.retry}
        </button>
      </div>
    );
  }
  return <>{children(value.data)}</>;
}

export function Empty({ children }: { children: ReactNode }) {
  return <p className="state empty">{children}</p>;
}

/**
 * A table that scrolls sideways on a phone instead of squeezing. The
 * scrolling box takes keyboard focus, so its hidden columns can be reached
 * without a pointer.
 */
export function Table(
  { head, children, caption }: {
    head: ReactNode[];
    children: ReactNode;
    caption?: string;
  },
) {
  const copy = useCopy();
  return (
    <div
      className="table-wrap"
      tabIndex={0}
      role="region"
      aria-label={caption ?? copy.table}
    >
      <table>
        {caption ? <caption>{caption}</caption> : null}
        <thead>
          <tr>
            {head.map((cell, index) => <th key={index} scope="col">{cell}</th>)}
          </tr>
        </thead>
        <tbody>{children}</tbody>
      </table>
    </div>
  );
}

export function Pill(
  { tone = "neutral", children }: {
    tone?: "neutral" | "good" | "warn" | "muted";
    children: ReactNode;
  },
) {
  return <span className={`pill ${tone}`}>{children}</span>;
}

/** A question in a modal; resolves with the person's answer. */
export function Confirm(
  { title, text, confirm, danger, onAnswer }: {
    title: string;
    text: string;
    confirm: string;
    danger?: boolean;
    onAnswer: (yes: boolean) => void;
  },
) {
  const copy = useCopy();
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const dialog = ref.current;
    if (dialog && !dialog.open) dialog.showModal();
  }, []);
  return (
    <dialog
      ref={ref}
      className="dialog"
      aria-labelledby="confirm-title"
      onCancel={() => onAnswer(false)}
    >
      <h2 id="confirm-title">{title}</h2>
      <p>{text}</p>
      <div className="dialog-actions">
        <button
          type="button"
          className="btn ghost"
          onClick={() => onAnswer(false)}
        >
          {copy.cancel}
        </button>
        <button
          type="button"
          className={`btn ${danger ? "danger" : ""}`}
          onClick={() => onAnswer(true)}
        >
          {confirm}
        </button>
      </div>
    </dialog>
  );
}

/** Holds one pending question; `ask` resolves when it is answered. */
export function useConfirm() {
  const [question, setQuestion] = useState<
    | null
    | {
      title: string;
      text: string;
      confirm: string;
      danger?: boolean;
      resolve: (yes: boolean) => void;
    }
  >(null);
  const ask = (
    q: { title: string; text: string; confirm: string; danger?: boolean },
  ) => new Promise<boolean>((resolve) => setQuestion({ ...q, resolve }));
  const dialog = question
    ? (
      <Confirm
        {...question}
        onAnswer={(yes) => {
          question.resolve(yes);
          setQuestion(null);
        }}
      />
    )
    : null;
  return { ask, dialog };
}

/** A short message after an action, read out by screen readers. */
export function Notice(
  { tone = "good", children }: { tone?: "good" | "bad"; children: ReactNode },
) {
  return <p className={`notice ${tone}`} role="status">{children}</p>;
}

interface TurnstileApi {
  render: (element: HTMLElement, options: Record<string, unknown>) => string;
  remove: (id: string) => void;
}

/** Cloudflare's script puts its API on the global object once loaded. */
function turnstileApi(): TurnstileApi | undefined {
  return (globalThis as { turnstile?: TurnstileApi }).turnstile;
}

let turnstileScript: Promise<void> | null = null;
function loadTurnstile(): Promise<void> {
  turnstileScript ??= new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src =
      "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
    script.async = true;
    script.onload = () => resolve();
    script.onerror = () => reject(new Error("TURNSTILE_UNAVAILABLE"));
    document.head.appendChild(script);
  });
  return turnstileScript;
}

/**
 * Cloudflare's check that a person, not a bot, is asking. Nothing renders
 * when the build has no site key (the API then asks for none).
 */
export function Turnstile(
  { onToken, lang }: { onToken: (token: string | null) => void; lang: string },
) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (!portalConfig.turnstileSiteKey || !ref.current) return;
    let widget: string | null = null;
    let live = true;
    loadTurnstile().then(() => {
      const turnstile = turnstileApi();
      if (!live || !ref.current || !turnstile) return;
      widget = turnstile.render(ref.current, {
        sitekey: portalConfig.turnstileSiteKey,
        language: lang,
        callback: (token: string) => onToken(token),
        "expired-callback": () => onToken(null),
        "error-callback": () => onToken(null),
      });
    }).catch(() => onToken(null));
    return () => {
      live = false;
      if (widget) turnstileApi()?.remove(widget);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [lang]);
  if (!portalConfig.turnstileSiteKey) return null;
  return <div ref={ref} className="turnstile" />;
}

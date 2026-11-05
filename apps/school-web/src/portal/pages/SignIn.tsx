import { useState } from "react";
import { signIn } from "../auth";
import { portalConfig, type Provider } from "../config";
import { useCopy } from "../i18n";
import { basePath } from "../router";

/** Three ways in, as each company asks its button to look (plan 5.1). */
export function SignIn({ error }: { error?: "cancelled" | "failed" }) {
  const copy = useCopy();
  const [failed, setFailed] = useState(error ?? null);
  const providers = portalConfig.providers;
  const configured = Boolean(
    portalConfig.supabaseUrl && portalConfig.supabaseKey,
  );
  const legal = copy.lang === "ar"
    ? "https://legal.studafy.com/ar"
    : "https://legal.studafy.com";

  async function start(provider: Provider) {
    setFailed(null);
    try {
      await signIn(provider, basePath());
    } catch {
      setFailed("failed");
    }
  }

  return (
    <main className="signin">
      <div className="signin-card">
        <img src="/brand/logo.svg" alt="Studafy" width={128} height={40} />
        <h1>{copy.signIn.title}</h1>
        <p className="muted">{copy.signIn.text}</p>
        {!configured
          ? (
            <p className="notice bad" role="alert">
              {copy.signIn.notConfigured}
            </p>
          )
          : (
            <div className="providers">
              {providers.includes("apple") && (
                <button
                  type="button"
                  className="provider apple"
                  onClick={() => start("apple")}
                >
                  <AppleMark /> {copy.signIn.apple}
                </button>
              )}
              {providers.includes("google") && (
                <button
                  type="button"
                  className="provider google"
                  onClick={() => start("google")}
                >
                  <GoogleMark /> {copy.signIn.google}
                </button>
              )}
              {providers.includes("azure") && (
                <>
                  <button
                    type="button"
                    className="provider microsoft"
                    onClick={() => start("azure")}
                  >
                    <MicrosoftMark /> {copy.signIn.azure}
                  </button>
                  <p className="hint">{copy.signIn.azureHint}</p>
                </>
              )}
            </div>
          )}
        {failed && (
          <p className="notice bad" role="alert">
            {failed === "cancelled"
              ? copy.signIn.cancelled
              : copy.signIn.failed}
          </p>
        )}
        <p className="hint">{copy.signIn.sameWay}</p>
        <p className="fine">
          {copy.signIn.agree} <a href={`${legal}/terms`}>{copy.signIn.terms}</a>
          {" · "}
          <a href={`${legal}/privacy`}>{copy.signIn.privacy}</a>
        </p>
      </div>
    </main>
  );
}

function AppleMark() {
  return (
    <svg
      viewBox="0 0 24 24"
      width="18"
      height="18"
      aria-hidden="true"
      fill="currentColor"
    >
      <path d="M16.4 12.6c0-2.4 2-3.6 2.1-3.6-1.1-1.7-2.9-1.9-3.5-1.9-1.5-.2-2.9.9-3.7.9-.8 0-1.9-.9-3.2-.8-1.6 0-3.1 1-4 2.4-1.7 3-.4 7.4 1.2 9.8.8 1.2 1.8 2.5 3 2.4 1.2 0 1.7-.8 3.1-.8 1.5 0 1.9.8 3.2.8 1.3 0 2.2-1.2 3-2.4.9-1.4 1.3-2.7 1.3-2.8 0 0-2.5-1-2.5-4zM14 5.4c.7-.8 1.1-1.9 1-3-1 0-2.1.7-2.8 1.5-.6.7-1.2 1.8-1 2.9 1 .1 2.1-.6 2.8-1.4z" />
    </svg>
  );
}

function GoogleMark() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
      <path
        fill="#4285F4"
        d="M23.5 12.3c0-.8-.1-1.6-.2-2.3H12v4.5h6.5a5.6 5.6 0 0 1-2.4 3.6v3h3.9c2.3-2.1 3.5-5.2 3.5-8.8z"
      />
      <path
        fill="#34A853"
        d="M12 24c3.2 0 6-1.1 8-2.9l-3.9-3c-1.1.7-2.5 1.2-4.1 1.2-3.1 0-5.8-2.1-6.7-5H1.3v3.1A12 12 0 0 0 12 24z"
      />
      <path
        fill="#FBBC05"
        d="M5.3 14.3a7.2 7.2 0 0 1 0-4.6V6.6H1.3a12 12 0 0 0 0 10.8l4-3.1z"
      />
      <path
        fill="#EA4335"
        d="M12 4.8c1.8 0 3.3.6 4.6 1.8l3.4-3.4A12 12 0 0 0 1.3 6.6l4 3.1c.9-2.8 3.6-4.9 6.7-4.9z"
      />
    </svg>
  );
}

function MicrosoftMark() {
  return (
    <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true">
      <path fill="#F25022" d="M1 1h10.5v10.5H1z" />
      <path fill="#7FBA00" d="M12.5 1H23v10.5H12.5z" />
      <path fill="#00A4EF" d="M1 12.5h10.5V23H1z" />
      <path fill="#FFB900" d="M12.5 12.5H23V23H12.5z" />
    </svg>
  );
}

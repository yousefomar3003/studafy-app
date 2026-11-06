import { type FormEvent, useState } from "react";
import { AGREEMENT_VERSION, api, ApiError } from "../api";
import { isHiddenEmail } from "../auth";
import { portalConfig } from "../config";
import { errorText, useCopy } from "../i18n";
import { navigate } from "../router";
import { AgreementCheck, Turnstile } from "../ui";

type Kind = "public" | "private" | "international" | "other";

/** The school's page, active at once (plan 5.2). */
export function CreateSchool({ email, onCreated }: {
  email: string | null;
  onCreated: () => void;
}) {
  const copy = useCopy();
  const hidden = isHiddenEmail(email);
  const [name, setName] = useState("");
  const [country, setCountry] = useState("");
  const [city, setCity] = useState("");
  const [kind, setKind] = useState<Kind>("private");
  const [jobTitle, setJobTitle] = useState("");
  const [contactEmail, setContactEmail] = useState(hidden ? "" : (email ?? ""));
  const [authorised, setAuthorised] = useState(false);
  const [adult, setAdult] = useState(false);
  const [agreed, setAgreed] = useState(false);
  const [token, setToken] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const needsToken = Boolean(portalConfig.turnstileSiteKey);
  const ready = authorised && adult && agreed && (!needsToken || token) &&
    !busy;

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!ready) return;
    setBusy(true);
    setError(null);
    try {
      const { id } = await api.createOrg({
        name: name.trim(),
        country: country.trim(),
        city: city.trim(),
        kind,
        jobTitle: jobTitle.trim(),
        contactEmail: contactEmail.trim() || null,
        adult: true,
        agreementVersion: AGREEMENT_VERSION,
        ...(token ? { captchaToken: token } : {}),
      });
      onCreated();
      navigate({ name: "dashboard", org: id }, true);
    } catch (e) {
      setError(errorText(copy, e instanceof ApiError ? e.code : "generic"));
      setBusy(false);
    }
  }

  return (
    <main className="narrow">
      <h1>{copy.create.title}</h1>
      <form className="card form" onSubmit={submit}>
        <label>
          {copy.create.name}
          <input
            required
            minLength={2}
            maxLength={120}
            value={name}
            onChange={(e) => setName(e.target.value)}
            dir="auto"
          />
        </label>
        <div className="row">
          <label>
            {copy.create.country}
            <input
              required
              minLength={2}
              maxLength={80}
              value={country}
              onChange={(e) => setCountry(e.target.value)}
              dir="auto"
            />
          </label>
          <label>
            {copy.create.city}
            <input
              required
              maxLength={80}
              value={city}
              onChange={(e) => setCity(e.target.value)}
              dir="auto"
            />
          </label>
        </div>
        <label>
          {copy.create.kind}
          <select
            value={kind}
            onChange={(e) => setKind(e.target.value as Kind)}
          >
            {(["public", "private", "international", "other"] as const).map((
              value,
            ) => (
              <option key={value} value={value}>
                {copy.create.kinds[value]}
              </option>
            ))}
          </select>
        </label>
        <label>
          {copy.create.jobTitle}
          <input
            required
            minLength={2}
            maxLength={80}
            value={jobTitle}
            onChange={(e) => setJobTitle(e.target.value)}
            dir="auto"
          />
          <span className="hint">{copy.create.jobTitleHint}</span>
        </label>
        <label>
          {copy.create.contactEmail}
          <input
            type="email"
            required={hidden}
            maxLength={254}
            value={contactEmail}
            onChange={(e) => setContactEmail(e.target.value)}
            dir="ltr"
          />
          <span className="hint">
            {hidden
              ? copy.create.contactEmailRequired
              : copy.create.contactEmailHint}
          </span>
        </label>
        <label className="check">
          <input
            type="checkbox"
            checked={authorised}
            onChange={(e) => setAuthorised(e.target.checked)}
          />
          {copy.create.authorised}
        </label>
        <label className="check">
          <input
            type="checkbox"
            checked={adult}
            onChange={(e) => setAdult(e.target.checked)}
          />
          {copy.create.adult}
        </label>
        <AgreementCheck checked={agreed} onChange={setAgreed} />
        <Turnstile onToken={setToken} lang={copy.lang} />
        {error && <p className="notice bad" role="alert">{error}</p>}
        <button type="submit" className="btn" disabled={!ready}>
          {copy.create.submit}
        </button>
      </form>
    </main>
  );
}

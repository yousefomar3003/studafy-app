import { type FormEvent, useState } from "react";
import { api, ApiError, type Org } from "../api";
import { errorText, useCopy } from "../i18n";
import { navigate } from "../router";
import { Notice, useConfirm } from "../ui";

type Kind = "public" | "private" | "international" | "other";

/** School details, administrators, and closing the page (plan 5.7). */
export function Settings({ org, me, onChange }: {
  org: Org;
  me: string;
  onChange: () => void;
}) {
  const copy = useCopy();
  const { ask, dialog } = useConfirm();
  const [name, setName] = useState(org.name);
  const [country, setCountry] = useState(org.country);
  const [city, setCity] = useState(org.city);
  const [kind, setKind] = useState<Kind>(org.kind);
  const [contactEmail, setContactEmail] = useState(org.contactEmail ?? "");
  const [email, setEmail] = useState("");
  const [jobTitle, setJobTitle] = useState("");
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(
    null,
  );
  const [busy, setBusy] = useState(false);
  const seats = org.admins.length + org.invites.length;

  async function run(action: () => Promise<unknown>, done: string) {
    setBusy(true);
    setMessage(null);
    try {
      await action();
      setMessage({ ok: true, text: done });
      onChange();
      return true;
    } catch (e) {
      setMessage({
        ok: false,
        text: errorText(copy, e instanceof ApiError ? e.code : "generic"),
      });
      return false;
    } finally {
      setBusy(false);
    }
  }

  async function save(event: FormEvent) {
    event.preventDefault();
    await run(
      () =>
        api.updateOrg(org.id, {
          name: name.trim(),
          country: country.trim(),
          city: city.trim(),
          kind,
          contactEmail: contactEmail.trim() || null,
        }),
      copy.settings.saved,
    );
  }

  async function invite(event: FormEvent) {
    event.preventDefault();
    if (
      await run(
        () => api.inviteAdmin(org.id, email.trim(), jobTitle.trim()),
        copy.settings.inviteSent,
      )
    ) {
      setEmail("");
      setJobTitle("");
    }
  }

  async function remove(userId: string) {
    const yes = await ask({
      title: copy.settings.removeTitle,
      text: copy.settings.removeText,
      confirm: copy.settings.remove,
      danger: true,
    });
    if (!yes) return;
    if (
      await run(() => api.removeAdmin(org.id, userId), copy.settings.saved) &&
      userId === me
    ) {
      navigate({ name: "home" }, true);
    }
  }

  async function close() {
    const yes = await ask({
      title: copy.settings.closeTitle,
      text: copy.settings.closeText,
      confirm: copy.settings.closeConfirm,
      danger: true,
    });
    if (!yes) return;
    if (await run(() => api.closeOrg(org.id), copy.settings.saved)) {
      navigate({ name: "home" }, true);
    }
  }

  return (
    <>
      <h1>{copy.settings.title}</h1>
      {message && (
        <Notice tone={message.ok ? "good" : "bad"}>{message.text}</Notice>
      )}
      <form className="card form" onSubmit={save}>
        <h2>{copy.settings.details}</h2>
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
          {copy.create.contactEmail}
          <input
            type="email"
            maxLength={254}
            value={contactEmail}
            onChange={(e) => setContactEmail(e.target.value)}
            dir="ltr"
          />
        </label>
        <button type="submit" className="btn" disabled={busy}>
          {copy.save}
        </button>
      </form>

      <section className="card">
        <h2>{copy.settings.admins}</h2>
        <p className="muted">{copy.settings.adminsText}</p>
        <ul className="list">
          {org.admins.map((admin) => (
            <li key={admin.id}>
              <div>
                <strong dir="auto">
                  {admin.name}
                  {admin.id === me ? ` (${copy.settings.you})` : ""}
                </strong>
                <span className="muted" dir="auto">{admin.jobTitle}</span>
                <span className="muted" dir="ltr">{admin.email ?? ""}</span>
              </div>
              {org.admins.length > 1 && (
                <button
                  type="button"
                  className="btn ghost small"
                  disabled={busy}
                  onClick={() => remove(admin.id)}
                >
                  {copy.settings.remove}
                </button>
              )}
            </li>
          ))}
          {org.invites.map((invite) => (
            <li key={invite.id}>
              <div>
                <strong dir="ltr">{invite.email}</strong>
                <span className="muted" dir="auto">
                  {invite.jobTitle} · {copy.settings.pending}
                </span>
              </div>
            </li>
          ))}
        </ul>
        {seats < 3 && (
          <form className="form" onSubmit={invite}>
            <h3>{copy.settings.invite}</h3>
            <div className="row end">
              <label>
                {copy.settings.inviteEmail}
                <input
                  type="email"
                  required
                  maxLength={254}
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  dir="ltr"
                />
              </label>
              <label>
                {copy.settings.inviteJob}
                <input
                  required
                  minLength={2}
                  maxLength={80}
                  value={jobTitle}
                  onChange={(e) => setJobTitle(e.target.value)}
                  dir="auto"
                />
              </label>
              <button type="submit" className="btn" disabled={busy}>
                {copy.settings.inviteSend}
              </button>
            </div>
          </form>
        )}
      </section>

      <section className="card danger-zone">
        <h2>{copy.settings.closeTitle}</h2>
        <p>{copy.settings.closeText}</p>
        <button
          type="button"
          className="btn danger"
          disabled={busy}
          onClick={close}
        >
          {copy.settings.closeButton}
        </button>
      </section>
      {dialog}
    </>
  );
}

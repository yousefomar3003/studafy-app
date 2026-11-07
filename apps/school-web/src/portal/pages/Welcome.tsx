import { useState } from "react";
import { api, ApiError, type MyInvites } from "../api";
import { errorText, useCopy } from "../i18n";
import { navigate } from "../router";
import { AgreementCheck } from "../ui";

/** Signed in with no school yet: invitations to accept, or create one. */
export function Welcome({ invites, onJoined }: {
  invites: MyInvites["invites"];
  onJoined: () => void;
}) {
  const copy = useCopy();
  const [adult, setAdult] = useState(false);
  const [agreed, setAgreed] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function accept(inviteId: string) {
    setBusy(true);
    setError(null);
    try {
      const { orgId } = await api.acceptInvite(inviteId);
      onJoined();
      navigate({ name: "dashboard", org: orgId });
    } catch (e) {
      setError(errorText(copy, e instanceof ApiError ? e.code : "generic"));
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="narrow">
      <h1>{copy.welcome.title}</h1>
      <p className="muted">{copy.welcome.text}</p>
      {invites.length > 0 && (
        <section className="card">
          <h2>{copy.welcome.invitesTitle}</h2>
          <label className="check">
            <input
              type="checkbox"
              checked={adult}
              onChange={(e) => setAdult(e.target.checked)}
            />
            {copy.welcome.adultConfirm}
          </label>
          <AgreementCheck checked={agreed} onChange={setAgreed} />
          <ul className="list">
            {invites.map((invite) => (
              <li key={invite.id}>
                <div>
                  <strong dir="auto">{invite.org.name}</strong>
                  <span className="muted" dir="auto">
                    {invite.org.city} · {invite.jobTitle}
                  </span>
                  {invite.invitedBy && (
                    <span className="muted" dir="auto">
                      {copy.welcome.invitedBy}: {invite.invitedBy.name}
                    </span>
                  )}
                </div>
                <button
                  type="button"
                  className="btn"
                  disabled={!adult || !agreed || busy}
                  onClick={() => accept(invite.id)}
                >
                  {copy.welcome.accept}
                </button>
              </li>
            ))}
          </ul>
        </section>
      )}
      {error && <p className="notice bad" role="alert">{error}</p>}
      <button
        type="button"
        className="btn"
        onClick={() => navigate({ name: "new" })}
      >
        {copy.welcome.create}
      </button>
    </main>
  );
}

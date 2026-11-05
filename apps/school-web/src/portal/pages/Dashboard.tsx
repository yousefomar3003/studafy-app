import { type FormEvent, useState } from "react";
import { api, ApiError, type Dashboard as Data } from "../api";
import { portalConfig } from "../config";
import { formatDateTime, formatNumber } from "../format";
import { errorText, useCopy } from "../i18n";
import { useLoad } from "../load";
import { Empty, Loader, Notice, Turnstile } from "../ui";

/** The school's numbers, linking a teacher, and requests still waiting (5.3). */
export function Dashboard({ org }: { org: string }) {
  const copy = useCopy();
  const value = useLoad(() => api.dashboard(org), org);
  return (
    <>
      <h1>{copy.nav.dashboard}</h1>
      <LinkTeacher org={org} onSent={value.reload} />
      <Loader value={value} onRetry={value.reload}>
        {(data) => (
          <DashboardView data={data} org={org} onChange={value.reload} />
        )}
      </Loader>
    </>
  );
}

export function DashboardView({ data, org, onChange }: {
  data: Data;
  org: string;
  onChange: () => void;
}) {
  const copy = useCopy();
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  async function cancel(linkId: string) {
    setBusy(linkId);
    setError(null);
    try {
      await api.cancelLink(org, linkId);
      onChange();
    } catch (e) {
      setError(errorText(copy, e instanceof ApiError ? e.code : "generic"));
    } finally {
      setBusy(null);
    }
  }
  return (
    <>
      <div className="stats">
        <Stat
          label={copy.dashboard.linkedTeachers}
          value={formatNumber(data.linkedTeachers, copy.lang)}
        />
        <Stat
          label={copy.dashboard.classes}
          value={formatNumber(data.classes, copy.lang)}
        />
        <Stat
          label={copy.dashboard.students}
          value={formatNumber(data.students, copy.lang)}
        />
      </div>
      <section className="card">
        <h2>{copy.dashboard.waiting}</h2>
        {error && <Notice tone="bad">{error}</Notice>}
        {data.waiting.length === 0
          ? <Empty>{copy.dashboard.waitingEmpty}</Empty>
          : (
            <ul className="list">
              {data.waiting.map((item) => (
                <li key={item.id}>
                  <div>
                    <strong dir="auto">{item.teacher.name}</strong>
                    <span className="muted" dir="ltr">
                      {item.teacher.email ?? ""}
                    </span>
                    <span className="muted">
                      {formatDateTime(item.requestedAt, copy.lang)}
                    </span>
                  </div>
                  <button
                    type="button"
                    className="btn ghost"
                    disabled={busy === item.id}
                    onClick={() => cancel(item.id)}
                  >
                    {copy.dashboard.cancelRequest}
                  </button>
                </li>
              ))}
            </ul>
          )}
      </section>
    </>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="stat">
      <span className="stat-value">{value}</span>
      <span className="stat-label">{label}</span>
    </div>
  );
}

function LinkTeacher({ org, onSent }: { org: string; onSent: () => void }) {
  const copy = useCopy();
  const [studafyId, setStudafyId] = useState("");
  const [token, setToken] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [result, setResult] = useState<{ ok: boolean; text: string } | null>(
    null,
  );
  const needsToken = Boolean(portalConfig.turnstileSiteKey);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (busy || (needsToken && !token)) return;
    setBusy(true);
    setResult(null);
    try {
      await api.requestLink(org, studafyId.trim(), token ?? undefined);
      setResult({ ok: true, text: copy.dashboard.sent });
      setStudafyId("");
      onSent();
    } catch (e) {
      setResult({
        ok: false,
        text: errorText(copy, e instanceof ApiError ? e.code : "generic"),
      });
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="card form" onSubmit={submit}>
      <h2>{copy.dashboard.linkTitle}</h2>
      <p className="muted">{copy.dashboard.linkText}</p>
      <div className="row end">
        <label>
          {copy.dashboard.studafyId}
          <input
            required
            dir="ltr"
            inputMode="text"
            autoComplete="off"
            placeholder="TC-1234567890"
            pattern="^(?:[Tt][Cc]-)?[1-9][0-9]{9}$"
            value={studafyId}
            onChange={(e) => setStudafyId(e.target.value)}
          />
        </label>
        <button
          type="submit"
          className="btn"
          disabled={busy || (needsToken && !token)}
        >
          {copy.dashboard.send}
        </button>
      </div>
      <Turnstile onToken={setToken} lang={copy.lang} />
      {result && (
        <Notice tone={result.ok ? "good" : "bad"}>{result.text}</Notice>
      )}
    </form>
  );
}

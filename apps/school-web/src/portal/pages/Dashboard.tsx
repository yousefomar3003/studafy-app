import { type FormEvent, useState } from "react";
import { api, ApiError, type Dashboard as Data, type Overview } from "../api";
import { portalConfig } from "../config";
import { formatDateTime, formatNumber, formatPercent } from "../format";
import { errorText, useCopy } from "../i18n";
import { useLoad } from "../load";
import { hrefFor, navigate, type Route } from "../router";
import { Empty, Loader, Notice, Pill, Table, Turnstile } from "../ui";

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
      <OverviewSection org={org} />
    </>
  );
}

function OverviewSection({ org }: { org: string }) {
  const value = useLoad(() => api.overview(org), `${org}:overview`);
  return (
    <Loader value={value} onRetry={value.reload}>
      {(data) => <OverviewView data={data} org={org} />}
    </Loader>
  );
}

function go(route: Route) {
  return {
    href: hrefFor(route),
    onClick: (e: { preventDefault: () => void }) => {
      e.preventDefault();
      navigate(route);
    },
  };
}

/** Each class's numbers, and the students who need attention (13a.1). */
export function OverviewView({ data, org }: { data: Overview; org: string }) {
  const copy = useCopy();
  const lang = copy.lang;
  return (
    <>
      <section className="card">
        <h2>{copy.overview.title}</h2>
        {data.classes.length === 0
          ? <Empty>{copy.overview.classEmpty}</Empty>
          : (
            <Table
              head={[
                copy.classes.title,
                copy.classes.students,
                copy.overview.attendance,
                copy.overview.average,
                copy.overview.missing,
              ]}
            >
              {data.classes.map((c) => (
                <tr key={c.classroomId}>
                  <td>
                    <a
                      dir="auto"
                      {...go({
                        name: "class",
                        org,
                        classroom: c.classroomId,
                        tab: "students",
                      })}
                    >
                      {c.name}
                    </a>
                  </td>
                  <td>{formatNumber(c.students, lang)}</td>
                  <td>
                    <Meter value={c.attendanceRate} lang={lang} />
                  </td>
                  <td>
                    <Meter value={c.averageMark} lang={lang} />
                  </td>
                  <td>{formatNumber(c.missing, lang)}</td>
                </tr>
              ))}
            </Table>
          )}
      </section>
      <section className="card">
        <h2>{copy.overview.attentionTitle}</h2>
        <p className="muted">{copy.overview.attentionText}</p>
        {data.attention.length === 0
          ? <Empty>{copy.overview.attentionEmpty}</Empty>
          : (
            <ul className="list">
              {data.attention.map((a) => (
                <li key={`${a.studentId}:${a.classroomId}`}>
                  <div>
                    <strong dir="auto">{a.name}</strong>
                    <a
                      className="muted"
                      dir="auto"
                      {...go({
                        name: "class",
                        org,
                        classroom: a.classroomId,
                        tab: "students",
                      })}
                    >
                      {a.className}
                    </a>
                  </div>
                  <div className="reasons">
                    {a.reasons.map((r) => (
                      <Pill key={r} tone="warn">
                        {copy.overview.reasons[r]}
                        {r === "attendance"
                          ? ` · ${formatPercent(a.attendanceRate, lang)}`
                          : ""}
                        {r === "low_marks"
                          ? ` · ${formatPercent(a.averageMark, lang)}`
                          : ""}
                        {r === "missing_work"
                          ? ` · ${formatNumber(a.missing, lang)}`
                          : ""}
                      </Pill>
                    ))}
                  </div>
                </li>
              ))}
            </ul>
          )}
      </section>
    </>
  );
}

/** A rate as a number and a short bar (colour plus text, never colour alone). */
export function Meter({ value, lang }: { value: number | null; lang: string }) {
  if (value === null) return <span className="muted">—</span>;
  const tone = value < 0.5 ? "bad" : value < 0.85 ? "warn" : "good";
  const step = Math.round(Math.max(0, Math.min(1, value)) * 20) * 5;
  return (
    <span className="meter">
      <span className={`meter-bar ${tone}`}>
        <span className={`meter-fill w${step}`} />
      </span>
      {formatPercent(value, lang)}
    </span>
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

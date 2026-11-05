import { useState } from "react";
import {
  api,
  ApiError,
  type Assignments,
  type Attendance,
  type Lessons,
  type Marks,
  openFile,
  type PortalFile,
  type Roster,
  type Tests,
  type Wellbeing,
} from "../api";
import {
  formatDate,
  formatDateTime,
  formatDay,
  formatNumber,
  ofTotal,
} from "../format";
import { errorText, useCopy } from "../i18n";
import { useLoad } from "../load";
import {
  CLASS_TABS,
  type ClassTab,
  hrefFor,
  navigate,
  type Route,
} from "../router";
import { Empty, Loader, Pill, Table } from "../ui";

/** One class, read-only, in tabs (plan 5.6). */
export function ClassPage({ org, classroom, tab }: {
  org: string;
  classroom: string;
  tab: ClassTab;
}) {
  const copy = useCopy();
  const header = useLoad(() => api.classes(org), `${org}:classes`);
  const info = header.state === "ok"
    ? header.data.classes.find((c) => c.id === classroom)
    : undefined;
  return (
    <>
      <p>
        <a
          href={hrefFor({ name: "classes", org })}
          onClick={(e) => {
            e.preventDefault();
            navigate({ name: "classes", org });
          }}
        >
          ← {copy.classes.title}
        </a>
      </p>
      <h1 dir="auto">{info?.name ?? copy.loading}</h1>
      {info && (
        <p className="muted" dir="auto">
          {info.teachers.map((t) => t.name).join(", ")} ·{" "}
          {formatNumber(info.students, copy.lang)} {copy.classes.students}
        </p>
      )}
      <p className="readonly">{copy.classPage.readOnly}</p>
      <nav className="tabs" aria-label={info?.name ?? ""}>
        {CLASS_TABS.map((key) => {
          const route: Route = { name: "class", org, classroom, tab: key };
          return (
            <a
              key={key}
              href={hrefFor(route)}
              aria-current={key === tab ? "page" : undefined}
              onClick={(e) => {
                e.preventDefault();
                navigate(route);
              }}
            >
              {copy.classPage.tabs[key]}
            </a>
          );
        })}
      </nav>
      <ClassTabContent org={org} classroom={classroom} tab={tab} />
    </>
  );
}

function ClassTabContent({ org, classroom, tab }: {
  org: string;
  classroom: string;
  tab: ClassTab;
}) {
  const key = `${org}:${classroom}:${tab}`;
  const value = useLoad<unknown>(() => {
    switch (tab) {
      case "students":
        return api.roster(org, classroom);
      case "lessons":
        return api.lessons(org, classroom);
      case "assignments":
        return api.assignments(org, classroom);
      case "tests":
        return api.tests(org, classroom);
      case "marks":
        return api.marks(org, classroom);
      case "attendance":
        return api.attendance(org, classroom);
      case "wellbeing":
        return api.wellbeing(org, classroom);
    }
  }, key);
  return (
    <Loader value={value} onRetry={value.reload}>
      {(data) => {
        switch (tab) {
          case "students":
            return <StudentsTab data={data as Roster} org={org} />;
          case "lessons":
            return <LessonsTab data={data as Lessons} org={org} />;
          case "assignments":
            return (
              <AssignmentsTab
                data={data as Assignments}
                org={org}
                classroom={classroom}
              />
            );
          case "tests":
            return (
              <TestsTab data={data as Tests} org={org} classroom={classroom} />
            );
          case "marks":
            return <MarksTab data={data as Marks} />;
          case "attendance":
            return <AttendanceTab data={data as Attendance} />;
          case "wellbeing":
            return <WellbeingTab data={data as Wellbeing} />;
        }
      }}
    </Loader>
  );
}

export function StudentsTab(
  { data, org }: { data: Roster; org: string },
) {
  const copy = useCopy();
  if (data.students.length === 0) return <Empty>{copy.students.empty}</Empty>;
  return (
    <Table
      head={[
        copy.students.name,
        copy.students.email,
        copy.students.studafyId,
        copy.students.parents,
      ]}
    >
      {data.students.map((s) => (
        <tr key={s.studentId}>
          <td>
            <a
              dir="auto"
              href={hrefFor({ name: "student", org, student: s.studentId })}
              onClick={(e) => {
                e.preventDefault();
                navigate({ name: "student", org, student: s.studentId });
              }}
            >
              {s.name}
            </a>
          </td>
          <td dir="ltr">{s.email ?? "—"}</td>
          <td dir="ltr">{s.studafyId ?? "—"}</td>
          <td>
            {s.parents.length === 0
              ? <span className="muted">{copy.students.noParents}</span>
              : s.parents.map((p, i) => (
                <div key={i}>
                  <span dir="auto">{p.name}</span>
                  {p.email && (
                    <span className="muted" dir="ltr">· {p.email}</span>
                  )}
                </div>
              ))}
          </td>
        </tr>
      ))}
    </Table>
  );
}

/** A file of the class, opened through a single-use link. */
export function FileButton({ org, file }: { org: string; file: PortalFile }) {
  const copy = useCopy();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const clean = file.scanState === "clean";
  return (
    <span className="file">
      <span dir="auto">{file.name ?? "file"}</span>
      <button
        type="button"
        className="btn ghost small"
        disabled={busy || !clean}
        title={clean ? undefined : copy.lessons.notReady}
        onClick={async () => {
          setBusy(true);
          setError(null);
          try {
            await openFile(org, file);
          } catch (e) {
            setError(
              errorText(
                copy,
                e instanceof ApiError ? e.code : "FILE_UNAVAILABLE",
              ),
            );
          } finally {
            setBusy(false);
          }
        }}
      >
        {busy ? copy.lessons.opening : copy.lessons.open}
      </button>
      {error && <span className="notice bad inline" role="alert">{error}</span>}
    </span>
  );
}

export function LessonsTab({ data, org }: { data: Lessons; org: string }) {
  const copy = useCopy();
  if (
    data.materials.length === 0 && data.announcements.length === 0 &&
    data.sessions.length === 0
  ) {
    return <Empty>{copy.lessons.empty}</Empty>;
  }
  return (
    <div className="stack">
      {data.announcements.length > 0 && (
        <section>
          <h2>{copy.lessons.announcements}</h2>
          {data.announcements.map((a) => (
            <article key={a.id} className="card">
              <h3 dir="auto">
                {a.title}{" "}
                {a.important && (
                  <Pill tone="warn">{copy.lessons.important}</Pill>
                )}
              </h3>
              <p className="muted">
                {formatDateTime(a.publishedAt, copy.lang)}
              </p>
              <p className="pre" dir="auto">{a.body}</p>
              {a.files.map((f) => (
                <FileButton key={f.fileId} org={org} file={f} />
              ))}
            </article>
          ))}
        </section>
      )}
      {data.materials.length > 0 && (
        <section>
          <h2>{copy.lessons.materials}</h2>
          {data.materials.map((m) => (
            <article key={m.id} className="card">
              <h3 dir="auto">{m.title}</h3>
              <p className="muted">
                {formatDateTime(m.publishedAt, copy.lang)}
              </p>
              {m.body && <p className="pre" dir="auto">{m.body}</p>}
              {m.files.map((f) => (
                <FileButton key={f.fileId} org={org} file={f} />
              ))}
              {m.links.map((l, i) => (
                <p key={i}>
                  <a
                    href={l.url}
                    rel="noopener noreferrer nofollow"
                    target="_blank"
                    dir="auto"
                  >
                    {l.title || l.url}
                  </a>
                </p>
              ))}
            </article>
          ))}
        </section>
      )}
      {data.sessions.length > 0 && (
        <section>
          <h2>{copy.lessons.sessions}</h2>
          <ul className="list compact">
            {data.sessions.map((s) => (
              <li key={s.id}>
                <span dir="auto">{s.title ?? "—"}</span>
                <span className="muted">
                  {formatDateTime(s.startsAt, copy.lang)}
                </span>
              </li>
            ))}
          </ul>
        </section>
      )}
    </div>
  );
}

export function AssignmentsTab({ data, org, classroom }: {
  data: Assignments;
  org: string;
  classroom: string;
}) {
  const copy = useCopy();
  if (data.assignments.length === 0) {
    return <Empty>{copy.assignments.empty}</Empty>;
  }
  return (
    <Table
      head={[
        copy.assignments.title,
        copy.assignments.due,
        copy.assignments.handedIn,
        "",
      ]}
    >
      {data.assignments.map((a) => {
        const route = {
          name: "handIns",
          org,
          classroom,
          assignment: a.id,
        } as const;
        return (
          <tr key={a.id}>
            <td dir="auto">{a.title}</td>
            <td>{formatDate(a.dueAt, copy.lang)}</td>
            <td>{ofTotal(a.handedIn, a.students, copy.lang)}</td>
            <td>
              <a
                href={hrefFor(route)}
                onClick={(e) => {
                  e.preventDefault();
                  navigate(route);
                }}
              >
                {copy.assignments.view}
              </a>
            </td>
          </tr>
        );
      })}
    </Table>
  );
}

export function TestsTab({ data, org, classroom }: {
  data: Tests;
  org: string;
  classroom: string;
}) {
  const copy = useCopy();
  if (data.tests.length === 0) return <Empty>{copy.tests.empty}</Empty>;
  return (
    <Table
      head={[
        copy.assignments.title,
        copy.assignments.due,
        copy.tests.sat,
        copy.tests.average,
        "",
      ]}
    >
      {data.tests.map((t) => {
        const route = { name: "answers", org, classroom, test: t.id } as const;
        return (
          <tr key={t.id}>
            <td dir="auto">{t.title}</td>
            <td>{formatDate(t.scheduledAt ?? t.opensAt, copy.lang)}</td>
            <td>{formatNumber(t.sat, copy.lang)}</td>
            <td>
              {t.averageScore === null
                ? "—"
                : `${formatNumber(t.averageScore, copy.lang)} / ${
                  formatNumber(t.maximumScore, copy.lang)
                }`}
            </td>
            <td>
              {t.delivery !== "paper" && (
                <a
                  href={hrefFor(route)}
                  onClick={(e) => {
                    e.preventDefault();
                    navigate(route);
                  }}
                >
                  {copy.tests.view}
                </a>
              )}
            </td>
          </tr>
        );
      })}
    </Table>
  );
}

/** Students × items; unpublished marks in italics, AI suggestions labelled. */
export function MarksTab({ data }: { data: Marks }) {
  const copy = useCopy();
  if (data.items.length === 0 || data.students.length === 0) {
    return <Empty>{copy.marks.empty}</Empty>;
  }
  const mark = new Map(
    data.marks.map((m) => [`${m.studentId}:${m.assessmentId}`, m]),
  );
  const suggested = new Map<string, number>();
  for (const s of data.suggestions) {
    if (s.suggestedScore === null) continue;
    const key = `${s.studentId}:${s.assessmentId}`;
    suggested.set(key, (suggested.get(key) ?? 0) + s.suggestedScore);
  }
  return (
    <>
      <p className="muted">{copy.marks.legend}</p>
      <Table
        head={[
          copy.marks.student,
          ...data.items.map((i) => <span key={i.id} dir="auto">{i.title}
          </span>),
        ]}
      >
        {data.students.map((s) => (
          <tr key={s.studentId}>
            <th scope="row" dir="auto">{s.name}</th>
            {data.items.map((item) => {
              const key = `${s.studentId}:${item.id}`;
              const m = mark.get(key);
              const ai = suggested.get(key);
              return (
                <td key={item.id}>
                  {m
                    ? (
                      <span
                        className={m.state === "published" ? "" : "unpublished"}
                        title={m.state === "published"
                          ? copy.marks.published
                          : copy.marks.notPublished}
                      >
                        {m.mark === "absent"
                          ? copy.marks.absent
                          : m.mark === "not_graded"
                          ? copy.marks.notGraded
                          : `${formatNumber(m.score, copy.lang)} / ${
                            formatNumber(item.maximumScore, copy.lang)
                          }`}
                      </span>
                    )
                    : "—"}
                  {ai !== undefined && (
                    <span className="ai" title={copy.marks.aiSuggestion}>
                      {" "}
                      <Pill tone="muted">
                        {copy.marks.aiSuggestion}: {formatNumber(ai, copy.lang)}
                      </Pill>
                    </span>
                  )}
                </td>
              );
            })}
          </tr>
        ))}
      </Table>
    </>
  );
}

/** Students × days, with each student's totals. */
export function AttendanceTab({ data }: { data: Attendance }) {
  const copy = useCopy();
  if (data.records.length === 0) return <Empty>{copy.attendance.empty}</Empty>;
  const days = [...new Set(data.records.map((r) => r.date))].sort().reverse()
    .slice(0, 31);
  const students = new Map<string, string>();
  for (const r of data.records) students.set(r.studentId, r.name);
  const cell = new Map<string, (typeof data.records)[number]["state"]>();
  const totals = new Map<string, Record<string, number>>();
  for (const r of data.records) {
    cell.set(`${r.studentId}:${r.date}`, r.state);
    const t = totals.get(r.studentId) ??
      { present: 0, absent: 0, late: 0, excused: 0 };
    t[r.state] = (t[r.state] ?? 0) + 1;
    totals.set(r.studentId, t);
  }
  const rows = [...students].sort((a, b) => a[1].localeCompare(b[1]));
  return (
    <Table
      head={[
        copy.attendance.student,
        ...days.map((d) => formatDay(d, copy.lang)),
        copy.attendance.totals,
      ]}
    >
      {rows.map(([id, name]) => {
        const t = totals.get(id)!;
        return (
          <tr key={id}>
            <th scope="row" dir="auto">{name}</th>
            {days.map((d) => {
              const state = cell.get(`${id}:${d}`);
              return (
                <td
                  key={d}
                  className={state ? `att ${state}` : ""}
                  title={state ? copy.attendance.states[state] : undefined}
                >
                  {state ? copy.attendance.short[state] : ""}
                </td>
              );
            })}
            <td className="totals">
              {(["present", "absent", "late", "excused"] as const).map((s) =>
                `${copy.attendance.short[s]} ${t[s] ?? 0}`
              ).join(" · ")}
            </td>
          </tr>
        );
      })}
    </Table>
  );
}

export function WellbeingTab({ data }: { data: Wellbeing }) {
  const copy = useCopy();
  if (data.notes.length === 0) return <Empty>{copy.wellbeing.empty}</Empty>;
  const kinds = copy.wellbeing.kinds as Record<string, string>;
  return (
    <div className="stack">
      {data.notes.map((n) => (
        <article key={n.id} className="card">
          <h3 dir="auto">
            {n.name} ·{" "}
            <Pill
              tone={n.kind === "concern"
                ? "warn"
                : n.kind === "strength"
                ? "good"
                : "neutral"}
            >
              {kinds[n.kind] ?? n.kind}
            </Pill>
          </h3>
          <p dir="auto">
            <strong>{n.title}</strong>
          </p>
          {n.context && <p className="pre" dir="auto">{n.context}</p>}
          {n.followUp && (
            <p className="pre" dir="auto">
              <strong>{copy.wellbeing.followUp}:</strong> {n.followUp}
            </p>
          )}
          <p className="muted">
            {formatDate(n.createdAt, copy.lang)}
            {n.author ? ` · ${copy.wellbeing.by} ${n.author}` : ""}
          </p>
        </article>
      ))}
    </div>
  );
}

export function useBack(org: string, classroom: string, tab: ClassTab) {
  const route: Route = { name: "class", org, classroom, tab };
  return { href: hrefFor(route), go: () => navigate(route) };
}

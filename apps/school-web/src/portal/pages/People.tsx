import { api, type StudentPage, type TeacherPage } from "../api";
import { formatDate, formatDateTime, formatNumber } from "../format";
import { useCopy } from "../i18n";
import { useLoad } from "../load";
import { hrefFor, navigate, type Route } from "../router";
import { Empty, Loader, Pill, Table } from "../ui";
import { Meter } from "./Dashboard";

function go(route: Route) {
  return {
    href: hrefFor(route),
    onClick: (e: { preventDefault: () => void }) => {
      e.preventDefault();
      navigate(route);
    },
  };
}

/** One student across every linked class (plan 13a.2). */
export function Student({ org, student }: { org: string; student: string }) {
  const value = useLoad(() => api.student(org, student), `${org}:${student}`);
  return (
    <Loader value={value} onRetry={value.reload}>
      {(data) => <StudentView data={data} org={org} />}
    </Loader>
  );
}

export function StudentView({ data, org }: { data: StudentPage; org: string }) {
  const copy = useCopy();
  const lang = copy.lang;
  const s = data.student;
  const kinds = copy.wellbeing.kinds as Record<string, string>;
  return (
    <>
      <h1 dir="auto">{s.name}</h1>
      <p className="muted">
        <span dir="ltr">{s.studafyId ?? ""}</span>
        {s.email
          ? (
            <>
              · <span dir="ltr">{s.email}</span>
            </>
          )
          : null}
      </p>
      <section className="card">
        <h2>{copy.students.parents}</h2>
        {s.parents.length === 0
          ? <Empty>{copy.students.noParents}</Empty>
          : (
            <ul className="list compact">
              {s.parents.map((p, i) => (
                <li key={i}>
                  <span dir="auto">{p.name}</span>
                  <span className="muted" dir="ltr">{p.email ?? ""}</span>
                </li>
              ))}
            </ul>
          )}
      </section>
      <section className="card">
        <h2>{copy.people.classes}</h2>
        <Table
          head={[
            copy.classes.title,
            copy.classes.teacher,
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
              <td dir="auto">{c.teachers.join(", ")}</td>
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
      </section>
      <section className="card">
        <h2>{copy.people.missingWork}</h2>
        {data.missingWork.length === 0
          ? <Empty>{copy.people.noMissing}</Empty>
          : (
            <ul className="list compact">
              {data.missingWork.map((m) => (
                <li key={m.assignmentId}>
                  <span dir="auto">{m.title} · {m.className}</span>
                  <span className="muted">
                    {copy.people.due}: {formatDate(m.dueAt, lang)}
                  </span>
                </li>
              ))}
            </ul>
          )}
      </section>
      <section className="card">
        <h2>{copy.people.recentMarks}</h2>
        {data.recentMarks.length === 0
          ? <Empty>{copy.people.noMarks}</Empty>
          : (
            <Table
              head={[
                copy.assignments.title,
                copy.classes.title,
                copy.people.mark,
                copy.teachers.status,
              ]}
            >
              {data.recentMarks.map((m) => (
                <tr key={m.assessmentId}>
                  <td dir="auto">{m.title}</td>
                  <td dir="auto">{m.className}</td>
                  <td className={m.state === "published" ? "" : "unpublished"}>
                    {m.mark === "absent"
                      ? copy.marks.absent
                      : m.mark === "not_graded"
                      ? copy.marks.notGraded
                      : `${formatNumber(m.score, lang)} / ${
                        formatNumber(m.maximumScore, lang)
                      }`}
                  </td>
                  <td>
                    <Pill tone={m.state === "published" ? "good" : "muted"}>
                      {m.state === "published"
                        ? copy.marks.published
                        : copy.marks.notPublished}
                    </Pill>
                  </td>
                </tr>
              ))}
            </Table>
          )}
      </section>
      <section className="card">
        <h2>{copy.people.wellbeing}</h2>
        {data.wellbeing.length === 0
          ? <Empty>{copy.people.noWellbeing}</Empty>
          : (
            <div className="stack">
              {data.wellbeing.map((w) => (
                <article key={w.id}>
                  <p dir="auto">
                    <Pill
                      tone={w.kind === "concern"
                        ? "warn"
                        : w.kind === "strength"
                        ? "good"
                        : "neutral"}
                    >
                      {kinds[w.kind] ?? w.kind}
                    </Pill>{" "}
                    <strong>{w.title}</strong>
                  </p>
                  {w.context && <p className="pre" dir="auto">{w.context}</p>}
                  <p className="muted" dir="auto">
                    {w.className} · {formatDate(w.createdAt, lang)}
                  </p>
                </article>
              ))}
            </div>
          )}
      </section>
    </>
  );
}

/** One linked teacher (plan 13a.3). */
export function Teacher({ org, teacher }: { org: string; teacher: string }) {
  const value = useLoad(() => api.teacher(org, teacher), `${org}:${teacher}`);
  return (
    <Loader value={value} onRetry={value.reload}>
      {(data) => <TeacherView data={data} org={org} />}
    </Loader>
  );
}

export function TeacherView({ data, org }: { data: TeacherPage; org: string }) {
  const copy = useCopy();
  const lang = copy.lang;
  const t = data.teacher;
  return (
    <>
      <h1 dir="auto">{t.name}</h1>
      <p className="muted">
        <span dir="ltr">{t.email ?? ""}</span>
        {t.linkedSince
          ? ` · ${copy.people.linkedSince} ${formatDate(t.linkedSince, lang)}`
          : ""}
      </p>
      <div className="stats">
        <div className="stat">
          <span className="stat-value">
            {formatNumber(data.classes.length, lang)}
          </span>
          <span className="stat-label">{copy.people.classes}</span>
        </div>
        <div className="stat">
          <span className="stat-value">
            {formatNumber(data.toMark.testAnswers, lang)}
          </span>
          <span className="stat-label">{copy.people.testAnswers}</span>
        </div>
        <div className="stat">
          <span className="stat-value">
            {formatNumber(data.toMark.handIns, lang)}
          </span>
          <span className="stat-label">{copy.people.handIns}</span>
        </div>
      </div>
      <section className="card">
        <h2>{copy.people.classes}</h2>
        {data.classes.length === 0
          ? <Empty>{copy.classes.empty}</Empty>
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
        <h2>{copy.people.recentLessons}</h2>
        {data.recentLessons.length === 0
          ? <Empty>{copy.people.noLessons}</Empty>
          : (
            <ul className="list compact">
              {data.recentLessons.map((l) => (
                <li key={l.id}>
                  <span dir="auto">{l.title ?? "—"} · {l.className}</span>
                  <span className="muted">
                    {formatDateTime(l.startsAt, lang)}
                  </span>
                </li>
              ))}
            </ul>
          )}
      </section>
    </>
  );
}

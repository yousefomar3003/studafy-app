import { useMemo, useState } from "react";
import { api, type Classes as Data } from "../api";
import { formatDate, formatNumber } from "../format";
import { useCopy } from "../i18n";
import { useLoad } from "../load";
import { hrefFor, navigate } from "../router";
import { Empty, Loader, Table } from "../ui";

/** Every class of every linked teacher, with search and filters (5.5). */
export function Classes({ org }: { org: string }) {
  const copy = useCopy();
  const value = useLoad(() => api.classes(org), org);
  const groups = { name: "groups", org } as const;
  return (
    <>
      <div className="title-row">
        <h1>{copy.classes.title}</h1>
        <a
          className="btn ghost small"
          href={hrefFor(groups)}
          onClick={(e) => {
            e.preventDefault();
            navigate(groups);
          }}
        >
          {copy.groups.open}
        </a>
      </div>
      <Loader value={value} onRetry={value.reload}>
        {(data) => <ClassesView data={data} org={org} />}
      </Loader>
    </>
  );
}

export function ClassesView({ data, org }: { data: Data; org: string }) {
  const copy = useCopy();
  const [search, setSearch] = useState("");
  const [teacher, setTeacher] = useState("");
  const [term, setTerm] = useState("");
  const teachers = useMemo(() => {
    const all = new Map<string, string>();
    for (const c of data.classes) {
      for (const t of c.teachers) all.set(t.id, t.name);
    }
    return [...all].sort((a, b) => a[1].localeCompare(b[1]));
  }, [data]);
  // Terms are named per teacher's workspace, so the filter goes by name.
  const terms = useMemo(
    () =>
      [...new Set(data.classes.flatMap((c) => c.term ? [c.term.name] : []))]
        .sort((a, b) => a.localeCompare(b)),
    [data],
  );
  if (data.classes.length === 0) return <Empty>{copy.classes.empty}</Empty>;
  const needle = search.trim().toLowerCase();
  const shown = data.classes.filter((c) =>
    (!teacher || c.teachers.some((t) => t.id === teacher)) &&
    (!term || c.term?.name === term) &&
    (!needle || c.name.toLowerCase().includes(needle) ||
      c.teachers.some((t) => t.name.toLowerCase().includes(needle)))
  );
  return (
    <>
      <div className="filters">
        <input
          type="search"
          placeholder={copy.classes.search}
          aria-label={copy.classes.search}
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          dir="auto"
        />
        <select
          aria-label={copy.classes.teacher}
          value={teacher}
          onChange={(e) => setTeacher(e.target.value)}
        >
          <option value="">{copy.classes.allTeachers}</option>
          {teachers.map(([id, name]) => (
            <option key={id} value={id}>{name}</option>
          ))}
        </select>
        {terms.length > 1 && (
          <select
            aria-label={copy.classes.term}
            value={term}
            onChange={(e) => setTerm(e.target.value)}
          >
            <option value="">{copy.classes.allTerms}</option>
            {terms.map((name) => (
              <option key={name} value={name}>{name}</option>
            ))}
          </select>
        )}
      </div>
      {shown.length === 0 ? <Empty>{copy.classes.noMatch}</Empty> : (
        <Table
          head={[
            copy.classes.title,
            copy.classes.teacher,
            copy.classes.term,
            copy.classes.students,
            copy.classes.lastActivity,
          ]}
        >
          {shown.map((c) => {
            const route = {
              name: "class",
              org,
              classroom: c.id,
              tab: "overview",
            } as const;
            return (
              <tr key={c.id}>
                <td>
                  <a
                    href={hrefFor(route)}
                    onClick={(e) => {
                      e.preventDefault();
                      navigate(route);
                    }}
                    dir="auto"
                  >
                    {c.name}
                  </a>
                  {(c.grade || c.section) && (
                    <span className="muted" dir="auto">
                      · {[c.grade, c.section].filter(Boolean).join(" ")}
                    </span>
                  )}
                </td>
                <td dir="auto">{c.teachers.map((t) => t.name).join(", ")}</td>
                <td dir="auto">{c.term?.name ?? "—"}</td>
                <td>{formatNumber(c.students, copy.lang)}</td>
                <td>{formatDate(c.lastActivityAt, copy.lang)}</td>
              </tr>
            );
          })}
        </Table>
      )}
    </>
  );
}

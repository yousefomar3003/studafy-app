import { useState } from "react";
import { api, ApiError, type Teachers as Data } from "../api";
import { formatDate, formatNumber } from "../format";
import { errorText, useCopy } from "../i18n";
import { useLoad } from "../load";
import { Empty, Loader, Notice, Pill, Table, useConfirm } from "../ui";

/** Every teacher asked or linked, with Unlink (plan 5.4). */
export function Teachers({ org }: { org: string }) {
  const copy = useCopy();
  const value = useLoad(() => api.teachers(org), org);
  return (
    <>
      <h1>{copy.teachers.title}</h1>
      <Loader value={value} onRetry={value.reload}>
        {(data) => (
          <TeachersView data={data} org={org} onChange={value.reload} />
        )}
      </Loader>
    </>
  );
}

export function TeachersView({ data, org, onChange }: {
  data: Data;
  org: string;
  onChange: () => void;
}) {
  const copy = useCopy();
  const { ask, dialog } = useConfirm();
  const [error, setError] = useState<string | null>(null);
  if (data.teachers.length === 0) return <Empty>{copy.teachers.empty}</Empty>;

  async function unlink(linkId: string) {
    const yes = await ask({
      title: copy.teachers.unlinkTitle,
      text: copy.teachers.unlinkText,
      confirm: copy.teachers.unlink,
      danger: true,
    });
    if (!yes) return;
    try {
      await api.unlinkTeacher(org, linkId);
      onChange();
    } catch (e) {
      setError(errorText(copy, e instanceof ApiError ? e.code : "generic"));
    }
  }

  return (
    <>
      {error && <Notice tone="bad">{error}</Notice>}
      <Table
        head={[
          copy.teachers.name,
          copy.teachers.email,
          copy.teachers.status,
          copy.teachers.classes,
          copy.teachers.since,
          "",
        ]}
      >
        {data.teachers.map((t) => (
          <tr key={t.linkId}>
            <td dir="auto">{t.name}</td>
            <td dir="ltr">{t.email ?? "—"}</td>
            <td>
              <Pill
                tone={t.status === "linked"
                  ? "good"
                  : t.status === "pending"
                  ? "warn"
                  : "muted"}
              >
                {copy.teachers.statuses[t.status]}
              </Pill>
            </td>
            <td>{formatNumber(t.classes, copy.lang)}</td>
            <td>{formatDate(t.decidedAt ?? t.requestedAt, copy.lang)}</td>
            <td>
              {t.status === "linked" && (
                <button
                  type="button"
                  className="btn ghost small"
                  onClick={() => unlink(t.linkId)}
                >
                  {copy.teachers.unlink}
                </button>
              )}
            </td>
          </tr>
        ))}
      </Table>
      {dialog}
    </>
  );
}

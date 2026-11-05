import { type FormEvent, useState } from "react";
import { api, ApiError, type Group, type Groups as Data } from "../api";
import { errorText, useCopy } from "../i18n";
import { useLoad } from "../load";
import { Empty, Loader, Notice, Pill, useConfirm } from "../ui";

type Message = { ok: boolean; text: string } | null;

/**
 * Class groups (plan 13a.7): one code for several linked classes. Each
 * class joins only once its teacher approves in the app.
 */
export function Groups({ org }: { org: string }) {
  const copy = useCopy();
  const groups = useLoad(() => api.groups(org), `${org}:groups`);
  const classes = useLoad(() => api.classes(org), `${org}:classes`);
  return (
    <>
      <h1>{copy.groups.title}</h1>
      <p className="muted group-intro">{copy.groups.text}</p>
      <NewGroup org={org} onMade={groups.reload} />
      <Loader value={groups} onRetry={groups.reload}>
        {(data) => (
          <GroupsView
            data={data}
            org={org}
            classes={classes.state === "ok" ? classes.data.classes : []}
            onChange={groups.reload}
          />
        )}
      </Loader>
    </>
  );
}

function NewGroup({ org, onMade }: { org: string; onMade: () => void }) {
  const copy = useCopy();
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<Message>(null);

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!name.trim() || busy) return;
    setBusy(true);
    setMessage(null);
    try {
      await api.createGroup(org, name.trim());
      setName("");
      onMade();
    } catch (e) {
      setMessage({
        ok: false,
        text: errorText(copy, e instanceof ApiError ? e.code : "generic"),
      });
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="card form" onSubmit={submit}>
      <h2>{copy.groups.newTitle}</h2>
      <label>
        {copy.groups.name}
        <input
          required
          maxLength={80}
          value={name}
          placeholder={copy.groups.namePlaceholder}
          onChange={(e) => setName(e.target.value)}
          dir="auto"
        />
      </label>
      {message && <Notice tone="bad">{message.text}</Notice>}
      <button type="submit" className="btn" disabled={!name.trim() || busy}>
        {copy.groups.create}
      </button>
    </form>
  );
}

export function GroupsView({ data, org, classes, onChange }: {
  data: Data;
  org: string;
  classes: { id: string; name: string }[];
  onChange: () => void;
}) {
  const copy = useCopy();
  if (data.groups.length === 0) return <Empty>{copy.groups.empty}</Empty>;
  return (
    <>
      {data.groups.map((group) => (
        <GroupCard
          key={group.id}
          group={group}
          org={org}
          classes={classes}
          onChange={onChange}
        />
      ))}
      <p className="fine">{copy.groups.note}</p>
    </>
  );
}

function GroupCard({ group, org, classes, onChange }: {
  group: Group;
  org: string;
  classes: { id: string; name: string }[];
  onChange: () => void;
}) {
  const copy = useCopy();
  const { ask, dialog } = useConfirm();
  const [adding, setAdding] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<Message>(null);
  const inGroup = new Set(
    group.classes.filter((c) => c.status !== "declined").map((c) =>
      c.classroomId
    ),
  );
  const addable = classes.filter((c) => !inGroup.has(c.id));

  async function act(run: () => Promise<unknown>, done?: string) {
    setBusy(true);
    setMessage(null);
    try {
      await run();
      if (done) setMessage({ ok: true, text: done });
      onChange();
    } catch (e) {
      setMessage({
        ok: false,
        text: errorText(copy, e instanceof ApiError ? e.code : "generic"),
      });
    } finally {
      setBusy(false);
    }
  }

  async function copyCode(code: string) {
    try {
      await navigator.clipboard.writeText(code);
      setMessage({ ok: true, text: copy.groups.copied });
    } catch { /* the code stays on screen to copy by hand */ }
  }

  async function renew() {
    const yes = await ask({
      title: copy.groups.newCodeTitle,
      text: copy.groups.newCodeText,
      confirm: copy.groups.newCode,
    });
    if (yes) await act(() => api.renewGroupCode(org, group.id));
  }

  async function close() {
    const yes = await ask({
      title: copy.groups.closeTitle,
      text: copy.groups.closeText,
      confirm: copy.groups.close,
      danger: true,
    });
    if (yes) await act(() => api.closeGroup(org, group.id));
  }

  return (
    <section className="card">
      <h2 dir="auto">{group.name}</h2>
      <div className="group-code">
        {group.code
          ? (
            <>
              <code aria-label={copy.groups.code}>{group.code}</code>
              <button
                type="button"
                className="btn ghost small"
                onClick={() => copyCode(group.code!)}
              >
                {copy.groups.copy}
              </button>
            </>
          )
          : <span className="muted">{copy.groups.noCode}</span>}
        <button
          type="button"
          className="btn ghost small"
          disabled={busy}
          onClick={renew}
        >
          {copy.groups.newCode}
        </button>
        <button
          type="button"
          className="btn ghost small"
          disabled={busy}
          onClick={close}
        >
          {copy.groups.close}
        </button>
      </div>
      <h3>{copy.groups.classesTitle}</h3>
      {group.classes.length === 0
        ? <Empty>{copy.groups.noClasses}</Empty>
        : (
          <ul className="list compact">
            {group.classes.map((c) => (
              <li key={c.id}>
                <div>
                  <strong dir="auto">{c.name}</strong>
                  <span className="muted" dir="auto">
                    {c.teachers.map((t) => t.name).join(", ")}
                  </span>
                </div>
                <span>
                  <Pill
                    tone={c.status === "approved"
                      ? "good"
                      : c.status === "pending"
                      ? "warn"
                      : "muted"}
                  >
                    {copy.groups.statuses[c.status]}
                  </Pill>{" "}
                  {c.status !== "declined" && (
                    <button
                      type="button"
                      className="btn ghost small"
                      disabled={busy}
                      onClick={() =>
                        act(() =>
                          api.removeGroupClass(org, group.id, c.classroomId)
                        )}
                    >
                      {copy.groups.remove}
                    </button>
                  )}
                </span>
              </li>
            ))}
          </ul>
        )}
      {addable.length > 0 && (
        <div className="group-add">
          <select
            aria-label={copy.groups.chooseClass}
            value={adding}
            onChange={(e) => setAdding(e.target.value)}
          >
            <option value="">{copy.groups.chooseClass}</option>
            {addable.map((c) => (
              <option key={c.id} value={c.id}>{c.name}</option>
            ))}
          </select>
          <button
            type="button"
            className="btn small"
            disabled={!adding || busy}
            onClick={() =>
              act(async () => {
                await api.addGroupClass(org, group.id, adding);
                setAdding("");
              }, copy.groups.added)}
          >
            {copy.groups.add}
          </button>
        </div>
      )}
      {message && (
        <Notice tone={message.ok ? "good" : "bad"}>{message.text}</Notice>
      )}
      {dialog}
    </section>
  );
}

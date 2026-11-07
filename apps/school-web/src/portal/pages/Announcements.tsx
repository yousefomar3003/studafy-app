import { type FormEvent, useState } from "react";
import {
  type AnnouncementRequest,
  type Announcements as Data,
  api,
  ApiError,
} from "../api";
import { formatDateTime, formatNumber } from "../format";
import { errorText, useCopy } from "../i18n";
import { useLoad } from "../load";
import { Empty, Loader, Notice, Pill, useConfirm } from "../ui";

type Audience = AnnouncementRequest["audience"];
const AUDIENCES: Audience[] = [
  "students_and_parents",
  "students",
  "parents",
  "teachers",
];

/** Announcements from the school (plan 13a.6): write, send, and what was sent. */
export function Announcements({ org }: { org: string }) {
  const copy = useCopy();
  const sent = useLoad(() => api.announcements(org), `${org}:announcements`);
  const classes = useLoad(() => api.classes(org), `${org}:classes`);
  return (
    <>
      <h1>{copy.announcements.title}</h1>
      <Composer
        org={org}
        classes={classes.state === "ok" ? classes.data.classes : []}
        onSent={sent.reload}
      />
      <section className="card">
        <h2>{copy.announcements.sentTitle}</h2>
        <Loader value={sent} onRetry={sent.reload}>
          {(data) => <SentList data={data} />}
        </Loader>
      </section>
    </>
  );
}

function Composer({ org, classes, onSent }: {
  org: string;
  classes: { id: string; name: string }[];
  onSent: () => void;
}) {
  const copy = useCopy();
  const { ask, dialog } = useConfirm();
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [audience, setAudience] = useState<Audience>("students_and_parents");
  const [all, setAll] = useState(true);
  const [chosen, setChosen] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ ok: boolean; text: string } | null>(
    null,
  );
  const ready = title.trim() && body.trim() && (all || chosen.length > 0) &&
    !busy;

  async function submit(event: FormEvent) {
    event.preventDefault();
    if (!ready) return;
    const yes = await ask({
      title: copy.announcements.confirmTitle,
      text: copy.announcements.confirmText,
      confirm: copy.announcements.send,
    });
    if (!yes) return;
    setBusy(true);
    setMessage(null);
    try {
      const result = await api.sendAnnouncement(org, {
        title: title.trim(),
        body: body.trim(),
        audience,
        ...(all ? {} : { classroomIds: chosen }),
      });
      setMessage({
        ok: true,
        text: copy.announcements.sent.replace(
          "{count}",
          formatNumber(result.recipients, copy.lang),
        ),
      });
      setTitle("");
      setBody("");
      onSent();
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
      <h2>{copy.announcements.newTitle}</h2>
      <p className="muted">{copy.announcements.note}</p>
      <label>
        {copy.announcements.heading}
        <input
          required
          maxLength={120}
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          dir="auto"
        />
      </label>
      <label>
        {copy.announcements.body}
        <textarea
          required
          maxLength={4000}
          rows={5}
          value={body}
          onChange={(e) => setBody(e.target.value)}
          dir="auto"
        />
      </label>
      <label>
        {copy.announcements.audience}
        <select
          value={audience}
          onChange={(e) => setAudience(e.target.value as Audience)}
        >
          {AUDIENCES.map((a) => (
            <option key={a} value={a}>{copy.announcements.audiences[a]}</option>
          ))}
        </select>
      </label>
      <fieldset className="choices">
        <legend>{copy.announcements.classes}</legend>
        <label className="check">
          <input
            type="radio"
            name="classes"
            checked={all}
            onChange={() => setAll(true)}
          />
          {copy.announcements.allClasses}
        </label>
        <label className="check">
          <input
            type="radio"
            name="classes"
            checked={!all}
            onChange={() => setAll(false)}
          />
          {copy.announcements.chooseClasses}
        </label>
        {!all && (
          <div className="class-picks">
            {classes.map((c) => (
              <label key={c.id} className="check">
                <input
                  type="checkbox"
                  checked={chosen.includes(c.id)}
                  onChange={(e) =>
                    setChosen(
                      e.target.checked
                        ? [...chosen, c.id]
                        : chosen.filter((x) => x !== c.id),
                    )}
                />
                <span dir="auto">{c.name}</span>
              </label>
            ))}
          </div>
        )}
      </fieldset>
      {message && (
        <Notice tone={message.ok ? "good" : "bad"}>{message.text}</Notice>
      )}
      <button type="submit" className="btn" disabled={!ready}>
        {copy.announcements.send}
      </button>
      {dialog}
    </form>
  );
}

export function SentList({ data }: { data: Data }) {
  const copy = useCopy();
  if (data.announcements.length === 0) {
    return <Empty>{copy.announcements.empty}</Empty>;
  }
  return (
    <div className="stack">
      {data.announcements.map((a) => (
        <article key={a.id} className="sent">
          <h3 dir="auto">
            {a.title}{" "}
            {a.removed && <Pill tone="warn">{copy.announcements.removed}</Pill>}
          </h3>
          <p className="pre" dir="auto">{a.body}</p>
          <p className="muted">
            {copy.announcements.audiences[a.audience]} ·{" "}
            {formatDateTime(a.createdAt, copy.lang)}
            {" · "}
            {copy.announcements.reached} {formatNumber(a.recipients, copy.lang)}
            {a.author ? ` · ${a.author}` : ""}
          </p>
        </article>
      ))}
    </div>
  );
}

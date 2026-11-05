import { api, type HandIns, type TestAnswers } from "../api";
import { formatDateTime, formatNumber } from "../format";
import { useCopy } from "../i18n";
import { useLoad } from "../load";
import { Empty, Loader, Pill } from "../ui";
import { FileButton, useBack } from "./ClassPage";

function Back({ org, classroom, tab }: {
  org: string;
  classroom: string;
  tab: "assignments" | "tests";
}) {
  const copy = useCopy();
  const back = useBack(org, classroom, tab);
  return (
    <p>
      <a
        href={back.href}
        onClick={(e) => {
          e.preventDefault();
          back.go();
        }}
      >
        ← {copy.classPage.tabs[tab]}
      </a>
    </p>
  );
}

/** Every student's hand-in for one assignment. */
export function HandInsPage({ org, classroom, assignment }: {
  org: string;
  classroom: string;
  assignment: string;
}) {
  const copy = useCopy();
  const value = useLoad(
    () => api.handIns(org, assignment),
    `${org}:${assignment}`,
  );
  return (
    <>
      <Back org={org} classroom={classroom} tab="assignments" />
      <h1>{copy.assignments.handInsTitle}</h1>
      <Loader value={value} onRetry={value.reload}>
        {(data) => <HandInsView data={data} org={org} />}
      </Loader>
    </>
  );
}

export function HandInsView({ data, org }: { data: HandIns; org: string }) {
  const copy = useCopy();
  if (data.handIns.length === 0) return <Empty>{copy.students.empty}</Empty>;
  return (
    <div className="stack">
      {data.handIns.map((h) => (
        <article key={h.studentId} className="card">
          <h3 dir="auto">
            {h.name} {h.excused
              ? <Pill tone="muted">{copy.assignments.excused}</Pill>
              : h.submittedAt
              ? (
                <Pill tone="good">
                  {formatDateTime(h.submittedAt, copy.lang)}
                </Pill>
              )
              : <Pill tone="warn">{copy.assignments.notHandedIn}</Pill>}
          </h3>
          {h.answerText
            ? <p className="pre answer" dir="auto">{h.answerText}</p>
            : h.submittedAt && (
              <p className="muted">{copy.assignments.noAnswer}</p>
            )}
          {h.files.map((f) => <FileButton key={f.fileId} org={org} file={f} />)}
        </article>
      ))}
    </div>
  );
}

/** Every student's answers to one online test. */
export function AnswersPage({ org, classroom, test }: {
  org: string;
  classroom: string;
  test: string;
}) {
  const copy = useCopy();
  const value = useLoad(() => api.testAnswers(org, test), `${org}:${test}`);
  return (
    <>
      <Back org={org} classroom={classroom} tab="tests" />
      <h1>{copy.tests.answersTitle}</h1>
      <Loader value={value} onRetry={value.reload}>
        {(data) => <AnswersView data={data} />}
      </Loader>
    </>
  );
}

export function AnswersView({ data }: { data: TestAnswers }) {
  const copy = useCopy();
  if (data.attempts.length === 0) return <Empty>{copy.tests.noAttempts}</Empty>;
  const questions = [...data.questions].sort((a, b) => a.position - b.position);
  return (
    <div className="stack">
      {data.attempts.map((attempt) => {
        const answers = new Map(attempt.answers.map((a) => [a.questionId, a]));
        return (
          <article key={attempt.attemptId} className="card">
            <h3 dir="auto">
              {attempt.name}
              {attempt.attemptNumber && attempt.attemptNumber > 1
                ? ` · ${copy.tests.attempt} ${attempt.attemptNumber}`
                : ""}
              {attempt.awardedScore !== null && (
                <>
                  <Pill tone="neutral">
                    {formatNumber(attempt.awardedScore, copy.lang)}
                  </Pill>
                </>
              )}
            </h3>
            <ol className="answers">
              {questions.map((q) => {
                const a = answers.get(q.id);
                const score = a?.awardedScore ?? a?.autoScore ?? null;
                return (
                  <li key={q.id}>
                    <p className="question" dir="auto">
                      {q.prompt ?? `${copy.tests.question} ${q.position}`}
                    </p>
                    <p className="pre answer" dir="auto">
                      {a?.answerText || (Array.isArray(a?.selected)
                        ? (a?.selected as unknown[]).join(", ")
                        : "") ||
                        copy.tests.noAnswer}
                    </p>
                    <p className="muted">
                      {score === null ? "—" : formatNumber(score, copy.lang)} /
                      {" "}
                      {formatNumber(q.maximumScore, copy.lang)}
                      {a?.feedback ? ` · ${a.feedback}` : ""}
                    </p>
                  </li>
                );
              })}
            </ol>
          </article>
        );
      })}
    </div>
  );
}

import { api, type Reports as Data } from "../api";
import { formatDay, formatNumber, formatPercent } from "../format";
import { useCopy } from "../i18n";
import { useLoad } from "../load";
import { hrefFor, navigate } from "../router";
import { Empty, Loader, Table } from "../ui";
import { Meter } from "./Dashboard";
import { ExportBar } from "../ExportBar";
import { fileName } from "../export";

/** Reports across classes (plan 13a.4). */
export function Reports({ org }: { org: string }) {
  const copy = useCopy();
  const value = useLoad(() => api.reports(org), `${org}:reports`);
  return (
    <>
      <h1>{copy.reports.title}</h1>
      <Loader value={value} onRetry={value.reload}>
        {(data) => (
          <>
            <ExportBar
              org={org}
              kind="reports"
              name={fileName(copy.reports.title)}
              rows={() => [
                [
                  copy.classes.title,
                  copy.classes.students,
                  copy.reports.rate,
                  copy.overview.average,
                  copy.reports.handIn,
                  ...(["below50", "from50", "from70", "from85"] as const).map((
                    b,
                  ) => copy.reports.bands[b]),
                ],
                ...data.classes.map((c) => [
                  c.name,
                  c.students,
                  c.attendanceRate === null
                    ? ""
                    : Math.round(c.attendanceRate * 100) + "%",
                  c.averageMark === null
                    ? ""
                    : Math.round(c.averageMark * 100) + "%",
                  c.handInRate === null
                    ? ""
                    : Math.round(c.handInRate * 100) + "%",
                  c.bands.below50,
                  c.bands.from50,
                  c.bands.from70,
                  c.bands.from85,
                ]),
              ]}
            />
            <ReportsView data={data} org={org} />
          </>
        )}
      </Loader>
    </>
  );
}

const BANDS = ["below50", "from50", "from70", "from85"] as const;

export function ReportsView({ data, org }: { data: Data; org: string }) {
  const copy = useCopy();
  const lang = copy.lang;
  if (data.classes.length === 0) return <Empty>{copy.classes.empty}</Empty>;
  return (
    <>
      <section className="card">
        <h2>{copy.reports.weeklyTitle}</h2>
        <p className="muted">{copy.reports.weeklyText}</p>
        <WeeklyChart weeks={data.weeks} />
        <details className="as-table">
          <summary>{copy.reports.asTable}</summary>
          <Table head={[copy.reports.weekOf, copy.reports.rate]}>
            {data.weeks.map((w) => (
              <tr key={w.weekStart}>
                <td>{formatDay(w.weekStart, lang)}</td>
                <td>
                  {w.attendanceRate === null
                    ? copy.reports.noData
                    : formatPercent(w.attendanceRate, lang)}
                </td>
              </tr>
            ))}
          </Table>
        </details>
      </section>

      <section className="card">
        <h2>{copy.reports.classesTitle}</h2>
        <Table
          head={[
            copy.classes.title,
            copy.classes.students,
            copy.reports.rate,
            copy.overview.average,
            copy.reports.handIn,
          ]}
        >
          {data.classes.map((c) => {
            const route = {
              name: "class",
              org,
              classroom: c.classroomId,
              tab: "overview",
            } as const;
            return (
              <tr key={c.classroomId}>
                <td>
                  <a
                    dir="auto"
                    href={hrefFor(route)}
                    onClick={(e) => {
                      e.preventDefault();
                      navigate(route);
                    }}
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
                <td>
                  <Meter value={c.handInRate} lang={lang} />
                </td>
              </tr>
            );
          })}
        </Table>
      </section>

      <section className="card">
        <h2>{copy.reports.bandsTitle}</h2>
        <p className="muted">{copy.reports.bandsText}</p>
        <ul className="legend" aria-hidden="true">
          {BANDS.map((band) => (
            <li key={band}>
              <span className={`swatch band-${band}`} />
              {copy.reports.bands[band]}
            </li>
          ))}
        </ul>
        <div className="band-rows">
          {data.classes.map((c) => (
            <BandRow key={c.classroomId} name={c.name} bands={c.bands} />
          ))}
        </div>
        <details className="as-table">
          <summary>{copy.reports.asTable}</summary>
          <Table
            head={[
              copy.classes.title,
              ...BANDS.map((b) => copy.reports.bands[b]),
            ]}
          >
            {data.classes.map((c) => (
              <tr key={c.classroomId}>
                <td dir="auto">{c.name}</td>
                {BANDS.map((b) => (
                  <td key={b}>{formatNumber(c.bands[b], lang)}</td>
                ))}
              </tr>
            ))}
          </Table>
        </details>
      </section>
    </>
  );
}

/**
 * Twelve weekly bars, one series: one colour, a recessive 0/50/100 % grid,
 * the latest week labelled, every bar's value on hover (its title) and a
 * hit area the full height of the plot.
 */
export function WeeklyChart({ weeks }: { weeks: Data["weeks"] }) {
  const copy = useCopy();
  const lang = copy.lang;
  const width = 720;
  const height = 220;
  const top = 16;
  const bottom = 28;
  const left = 40;
  const plot = height - top - bottom;
  const slot = (width - left) / weeks.length;
  const bar = Math.min(28, slot - 8);
  const y = (rate: number) => top + plot * (1 - rate);
  const last = [...weeks].reverse().find((w) => w.attendanceRate !== null);
  const summary = weeks
    .map((w) =>
      `${formatDay(w.weekStart, lang)}: ${
        w.attendanceRate === null
          ? copy.reports.noData
          : formatPercent(w.attendanceRate, lang)
      }`
    )
    .join(", ");
  return (
    <svg
      className="chart"
      viewBox={`0 0 ${width} ${height}`}
      role="img"
      aria-label={`${copy.reports.weeklyTitle}. ${summary}`}
    >
      {[0, 0.5, 1].map((g) => (
        <g key={g}>
          <line className="grid" x1={left} x2={width} y1={y(g)} y2={y(g)} />
          <text className="axis" x={left - 6} y={y(g) + 4} textAnchor="end">
            {formatPercent(g, lang)}
          </text>
        </g>
      ))}
      {weeks.map((w, i) => {
        const x = left + i * slot + (slot - bar) / 2;
        const label = `${copy.reports.weekOf} ${
          formatDay(w.weekStart, lang)
        }: ${
          w.attendanceRate === null
            ? copy.reports.noData
            : formatPercent(w.attendanceRate, lang)
        }`;
        const rate = w.attendanceRate;
        const h = rate === null ? 0 : Math.max(2, plot * rate);
        const r = Math.min(4, h / 2);
        const yTop = top + plot - h;
        return (
          <g key={w.weekStart} className="bar-group">
            <title>{label}</title>
            <rect
              className="hit"
              x={left + i * slot}
              y={top}
              width={slot}
              height={plot}
            />
            {rate !== null && (
              <path
                className="bar"
                d={`M${x},${top + plot} V${yTop + r} Q${x},${yTop} ${
                  x + r
                },${yTop} H${x + bar - r} Q${x + bar},${yTop} ${x + bar},${
                  yTop + r
                } V${top + plot} Z`}
              />
            )}
            {i % 2 === 1 && (
              <text
                className="axis"
                x={x + bar / 2}
                y={height - 8}
                textAnchor="middle"
              >
                {formatDay(w.weekStart, lang)}
              </text>
            )}
            {w === last && rate !== null && (
              <text
                className="value"
                x={x + bar / 2}
                y={yTop - 6}
                textAnchor="middle"
              >
                {formatPercent(rate, lang)}
              </text>
            )}
          </g>
        );
      })}
    </svg>
  );
}

/** One class's marks across the four bands, as one 100 % bar. */
function BandRow(
  { name, bands }: { name: string; bands: Data["classes"][number]["bands"] },
) {
  const copy = useCopy();
  const lang = copy.lang;
  const total = BANDS.reduce((sum, b) => sum + bands[b], 0);
  const width = 600;
  const gap = 2;
  let x = 0;
  return (
    <div className="band-row">
      <span className="band-name" dir="auto">{name}</span>
      {total === 0 ? <span className="muted">{copy.reports.noData}</span> : (
        <svg
          className="band-bar"
          viewBox={`0 0 ${width} 16`}
          preserveAspectRatio="none"
          role="img"
          aria-label={`${name}: ${
            BANDS.map((b) => `${copy.reports.bands[b]} ${bands[b]}`).join(
              ", ",
            )
          }`}
        >
          {BANDS.map((b) => {
            const w = (bands[b] / total) * width;
            const start = x;
            x += w;
            if (w <= 0) return null;
            return (
              <rect
                key={b}
                className={`band-${b}`}
                x={start}
                y={0}
                width={Math.max(1, w - gap)}
                height={16}
                rx={3}
              >
                <title>
                  {`${copy.reports.bands[b]}: ${
                    formatNumber(bands[b], lang)
                  } ${copy.reports.marks} (${
                    formatPercent(bands[b] / total, lang)
                  })`}
                </title>
              </rect>
            );
          })}
        </svg>
      )}
      <span className="muted band-total">{formatNumber(total, lang)}</span>
    </div>
  );
}

/** Dates and numbers in the reader's language (Latin digits in both). */
function locale(lang: string): string {
  return lang === "ar" ? "ar-JO-u-nu-latn" : "en-GB";
}

export function formatDate(
  value: string | null | undefined,
  lang: string,
): string {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return new Intl.DateTimeFormat(locale(lang), { dateStyle: "medium" }).format(
    date,
  );
}

export function formatDateTime(
  value: string | null | undefined,
  lang: string,
): string {
  if (!value) return "—";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "—";
  return new Intl.DateTimeFormat(locale(lang), {
    dateStyle: "medium",
    timeStyle: "short",
  }).format(date);
}

/** A plain calendar date (YYYY-MM-DD) as a short day label. */
export function formatDay(value: string, lang: string): string {
  const [y, m, d] = value.split("-").map(Number);
  if (!y || !m || !d) return value;
  return new Intl.DateTimeFormat(locale(lang), {
    day: "numeric",
    month: "short",
    timeZone: "UTC",
  }).format(Date.UTC(y, m - 1, d));
}

export function formatNumber(
  value: number | null | undefined,
  lang: string,
): string {
  if (value === null || value === undefined || Number.isNaN(value)) return "—";
  return new Intl.NumberFormat(locale(lang), { maximumFractionDigits: 2 })
    .format(value);
}

/** "n of m", for hand-ins and tests. */
export function ofTotal(part: number, total: number, lang: string): string {
  return `${formatNumber(part, lang)} / ${formatNumber(total, lang)}`;
}

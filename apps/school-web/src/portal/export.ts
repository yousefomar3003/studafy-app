import { api } from "./api";

export type ExportKind =
  | "students"
  | "marks"
  | "attendance"
  | "reports"
  | "class";
export type Cell = string | number | null | undefined;

/**
 * One CSV cell. A cell that a spreadsheet would read as a formula (=, +, -,
 * @, or a tab or return first) gets a leading apostrophe, so a name or an
 * answer typed by someone else can never run in the school's Excel.
 */
export function csvCell(value: Cell): string {
  if (value === null || value === undefined) return "";
  let text = String(value);
  if (typeof value === "string" && /^[=+\-@\t\r]/.test(text)) text = `'${text}`;
  return /[",\n\r]/.test(text) ? `"${text.replaceAll('"', '""')}"` : text;
}

/** Rows as CSV, with a byte-order mark so Excel reads Arabic correctly. */
export function toCsv(rows: Cell[][]): string {
  return "﻿" + rows.map((row) => row.map(csvCell).join(",")).join("\r\n") +
    "\r\n";
}

/** A file name from parts, safe on every system. */
export function fileName(...parts: string[]): string {
  return parts.join(" - ").replace(/[\\/:*?"<>|]+/g, "").replace(/\s+/g, " ")
    .trim()
    .slice(0, 120) + ".csv";
}

/** Records the export, then downloads the file (plan 13a.5). */
export async function downloadCsv(
  org: string,
  kind: ExportKind,
  name: string,
  rows: Cell[][],
  classroomId?: string,
): Promise<void> {
  await api.recordExport(org, {
    kind,
    format: "csv",
    ...(classroomId ? { classroomId } : {}),
  });
  const url = URL.createObjectURL(
    new Blob([toCsv(rows)], { type: "text/csv;charset=utf-8" }),
  );
  const link = document.createElement("a");
  link.href = url;
  link.download = name;
  link.click();
  setTimeout(() => URL.revokeObjectURL(url), 60_000);
}

/** Records the export, then opens the browser's print (Save as PDF). */
export async function printPdf(
  org: string,
  kind: ExportKind,
  classroomId?: string,
): Promise<void> {
  await api.recordExport(org, {
    kind,
    format: "pdf",
    ...(classroomId ? { classroomId } : {}),
  });
  print();
}

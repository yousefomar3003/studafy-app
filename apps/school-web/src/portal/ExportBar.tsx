import { useState } from "react";
import { type Cell, downloadCsv, type ExportKind, printPdf } from "./export";
import { useCopy } from "./i18n";

/**
 * "Download for Excel" and "Print or save as PDF" for one view. Nothing is
 * exported unless the server has recorded it first.
 */
export function ExportBar({ org, kind, name, rows, classroomId }: {
  org: string;
  kind: ExportKind;
  name: string;
  rows: () => Cell[][];
  classroomId?: string;
}) {
  const copy = useCopy();
  const [busy, setBusy] = useState(false);
  const [failed, setFailed] = useState(false);
  async function run(action: () => Promise<void>) {
    setBusy(true);
    setFailed(false);
    try {
      await action();
    } catch {
      setFailed(true);
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="export-bar no-print">
      <button
        type="button"
        className="btn ghost small"
        disabled={busy}
        onClick={() =>
          run(() => downloadCsv(org, kind, name, rows(), classroomId))}
      >
        {copy.exports.csv}
      </button>
      <button
        type="button"
        className="btn ghost small"
        disabled={busy}
        onClick={() => run(() => printPdf(org, kind, classroomId))}
      >
        {copy.exports.pdf}
      </button>
      {failed && (
        <span className="notice bad inline" role="alert">
          {copy.exports.failed}
        </span>
      )}
    </div>
  );
}

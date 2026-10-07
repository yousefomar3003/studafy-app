/**
 * The rename-and-wrap rule of ADR-0030, as a pure function so it can be
 * tested apart from git.
 *
 * Extending a SQL function by renaming it to `<name>_pre_<change>` (or
 * `_before_`) and delegating to it is what grew private.authz_authorize to
 * twenty nested calls. After 202609280001 a migration may not leave such a
 * layer in the schema. An applied migration cannot be edited, so a wrap that
 * slipped in is accepted once a later migration has unwound it: renamed the
 * history-named function to a name for what it does, or dropped it.
 * Anything else is reported.
 */

export interface MigrationText {
  /** Path, sorting in replay order. */
  file: string;
  text: string;
}

export interface UnresolvedWrap {
  file: string;
  /** The history-named function the migration created by renaming. */
  name: string;
}

const HISTORY_NAME = /_(?:pre|before)_/i;
const RENAME =
  /\balter\s+function\s+private\.([a-z0-9_]+)\s*\([^)]*\)\s+rename\s+to\s+([a-z0-9_]+)/gi;
const DROP =
  /\bdrop\s+function\s+(?:if\s+exists\s+)?private\.([a-z0-9_]+)\s*\(/gi;

/** Wraps made by migrations after [bannedAfter] that no later one unwinds. */
export function unresolvedWraps(
  migrations: readonly MigrationText[],
  bannedAfter: string,
): UnresolvedWrap[] {
  const ordered = [...migrations].sort((a, b) => a.file.localeCompare(b.file));
  const unresolved: UnresolvedWrap[] = [];
  ordered.forEach((migration, index) => {
    if (migration.file <= bannedAfter) return;
    for (const [, , target] of migration.text.matchAll(RENAME)) {
      if (!target || !HISTORY_NAME.test(target)) continue;
      const name = target.toLowerCase();
      const unwound = ordered.slice(index + 1).some((later) =>
        [...later.text.matchAll(RENAME)].some(([, from, to]) =>
          from?.toLowerCase() === name && !!to && !HISTORY_NAME.test(to)
        ) ||
        [...later.text.matchAll(DROP)].some(([, dropped]) =>
          dropped?.toLowerCase() === name
        )
      );
      if (!unwound) unresolved.push({ file: migration.file, name });
    }
  });
  return unresolved;
}

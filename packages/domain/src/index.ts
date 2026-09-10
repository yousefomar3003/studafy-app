/**
 * Pure domain policies. This package imports nothing external — no framework,
 * no SDK, no I/O. It is the innermost ring of the dependency graph and the
 * proof fixture for the architecture boundary checker.
 */

/** A score is valid only when both numbers are finite and 0 <= score <= maximum. */
export function isScoreInRange(score: number, maximum: number): boolean {
  return (
    Number.isFinite(score) &&
    Number.isFinite(maximum) &&
    maximum > 0 &&
    score >= 0 &&
    score <= maximum
  );
}

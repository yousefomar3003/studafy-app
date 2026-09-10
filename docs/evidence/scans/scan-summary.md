# Dependency, licence, and secret scan summary

ARC-001 deliverable. Evidence date: 2026-09-10. Artifacts in this directory
record point-in-time results; CI (`ci.yml`) is the reproducible gate that
re-runs the checks on every push.

## Results

| Scan | Runner | Result | Artifact |
|---|---|---|---|
| Secret scan (full available Git history, six commits) | gitleaks 8.x local + CI gitleaks-action v3 | **0 leaks** | `gitleaks-2026-09-10.txt`; rerun 2026-09-10 after Phase 1 gap fixes |
| Source snapshot scan (tracked + untracked, normally ignored files excluded) | gitleaks 8.x local | **0 leaks across 323 files** | Closing verification 2026-09-10 |
| Tracked sensitive filenames | `.github/scripts/check-sensitive-files.sh` | **PASS** | (CI; rerun locally 2026-09-10) |
| Known vulnerabilities (Dart + Bun lockfiles, recursive) | osv-scanner local + CI v2.5.1 | **0 known vulnerabilities** | `osv-2026-09-10.txt` |
| Bun dependency audit | `bun audit --audit-level high` | **No vulnerabilities found** | `bun-audit-2026-09-10.txt` |
| Bun runtime/tool dependency licences | generated from `node_modules` | 8 packages, **all MIT** | `bun-licence-inventory-2026-09-10.txt` |
| Dart dependency tree | `flutter pub deps` | 135 packages (130 hosted + 5 SDK) | `dart-dependency-tree-2026-09-10.txt` |
| Dart package licence patterns | generated from pub cache LICENSE files | 38 auto-classified (MIT/Apache/BSD/GPL), **~90 REVIEW**, 5 SDK (no local source) | `dart-licence-inventory-2026-09-10.txt` |

## Pinning status (verified)

- Bun 1.3.14; `bun install --frozen-lockfile` verified locally (no changes).
- Deno 2.9.6; `deno check --frozen=true`, `deno test --frozen=true` in CI.
- Flutter 3.47.1 stable / Dart ^3.13.1; `pubspec.lock` content-hashed.
- `@supabase/supabase-js` **2.116.0 exact** in every Edge Function import URL
  (pinned 2026-09-10, previously floating `@2`); `deno.lock` holds the
  integrity hash.
- Supabase CLI 2.117.0 as pinned devDependency.
- CI actions pinned by commit SHA; no deploy credentials in any job.

## Findings and gaps (supply-chain register)

1. **No automated licence gate.** ~90 Dart packages carry licences that the
   heuristic could not classify; a formal licence review (copyleft/
   attribution obligations) is open before store release. Candidate: add a
   licence-scanning CI job or `pana`-based check in Phase 1.
2. **No automated dependency-update or provenance/SBOM workflow** (matches the
   audit's supply-chain gap). New runtime dependencies require review per
   instructions.md.
3. GPL-pattern packages detected in the Dart inventory (2 hits) need
   confirmation they are dev-only/transitive and compatible with a store
   release; flagged for the licence review.
4. Secret-scan scope begins at the two-commit imported-history boundary
   (`docs/governance/git-history-boundary.md`); all six currently available
   commits are covered. Pre-baseline history does not exist locally and cannot
   be inspected.
5. osv-scanner covers Dart/Bun lockfiles only; Deno remote imports are covered
   by `deno.lock` integrity hashes instead of an advisory scan (acceptable,
   recorded).

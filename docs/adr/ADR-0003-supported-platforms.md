# ADR-0003: Supported platforms — Android and iOS only

Status: Accepted. Decision-log: DL-003. Date: 2026-09-10.

## Context

The repository contains generated scaffolds for Android, iOS, web, Linux,
macOS, and Windows. Only Android and iOS have real configuration, and both use
placeholder identity `com.example.studafy`. ARC-001 requires identifying
supported platforms and versions. Store submission is blocked by SEC-001/REL
controls until final identity, signing, and privacy declarations exist.

## Decision

- **Studafy commits to Android and iOS as the only supported platforms.**
- Generated `web/`, `linux/`, `macos/`, and `windows/` scaffolds are explicitly
  **non-production** and must not be deleted before a supported-platforms Git
  baseline decision; they receive no product investment and no release
  pipeline.
- Any future web client requires an approved decision covering audience,
  accessibility, session/CSRF model, and deployment, and must use the same
  `/v1` API contracts — never direct database access.
- Version baselines (2026-09-10): Flutter 3.47.1 (stable), Dart SDK ^3.13.1,
  iOS deployment target 15.0, Java/Gradle toolchain 17, Android builds blocked
  from release by SEC-001.
- Final application identity (bundle/application ID), signing, and privacy
  manifests remain deferred under REL-002 (DL-015).

## Consequences

- REL-002 planning can assume a two-platform store target.
- Desktop/web scaffolds may be pruned in a later, separately reviewed change
  once this ADR is the Git baseline.
- The version baselines above must be re-recorded whenever a toolchain pin
  changes in CI.

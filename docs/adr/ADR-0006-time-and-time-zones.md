# ADR-0006: Time storage and rendering

Status: Accepted. Decision-log: DL-007. Date: 2026-09-10.

## Context

The existing schema mixes timestamp styles and lacks `updated_at` on most
tables. Schools operate in Saudi Arabia; the product renders schedules,
attendance, and deadlines in local time and supports Arabic locale with
Gregorian/Hijri calendar preference.

## Decision

- Store all timestamps as **UTC `timestamptz not null`**.
- Render using each school's **IANA time zone**, initially `Asia/Riyadh` where
  configured; never store local wall-clock times for instants.
- Recurring schedules that are local by nature (weekday + local start/end in
  `class_schedules`) store explicit local time plus the owning school's time
  zone, and remain a Phase 2 schema concern.
- Mutable tables get `created_at`/`updated_at` maintained consistently;
  append-only tables omit `updated_at`.

## Consequences

- Phase 2 migrations normalize timestamp types and add `updated_at` handling.
- Client formatting uses `intl` with per-school locale/time zone; the existing
  calendar-preference enum stays a presentation concern.
- DST (Saudi Arabia currently observes none) introduces no special cases, but
  the rule remains time-zone-driven rather than offset-driven.

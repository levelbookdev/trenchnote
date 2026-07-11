# ADR 0016 — `readings.read_at`: when the gauge was actually read

**Status:** accepted · **Date:** 2026-07-11

## Context

A `readings` record has only `created` (server-set at insert). So a reading
transcribed from a paper timecard, or captured offline and synced days
later, is stamped with the *entry* time, not the *observation* time. The
June 2026 seed exposed it: odometers the timecard recorded on 2026-06-29 all
landed as "now." Meter numbers end up on equipment invoices — the month they
belong to is not cosmetic.

There is a direct precedent already in the tree. Inspections (ADR 0014)
carry `inspected_at` — client-set, date-only at UTC midnight — for exactly
this reason: "compliance math must survive offline queues and back-entry."
`readings` is the second append-only ledger; inspections is the third. The
second should get what the third already has.

## Decision

Add `read_at` to `readings`: `date`, client-set, date-only at UTC midnight,
**optional** (migration `1783468817`). Empty = unknown; the derivation falls
back to `created`. `created` still records system-entry time.

- **Set at capture time.** asset.html stamps `read_at` = today when the
  reading is taken, so it travels with the offline queue (ADR 0008) instead
  of being overwritten with the sync time.
- **Derivation shifts to `read_at` order** (mirroring how inspections sort
  `-inspected_at,-created`): latest reading = newest by `read_at`, ties and
  empties falling back to `created`; the lower-than-previous flag compares
  in that same order. Nothing is stored — still derived at render time.
- **Back-entry** of a historical reading (someone typing in an old
  timecard) is an admin-UI task, where `read_at` is set by hand.

## Alternatives rejected

- **Required `read_at`.** Breaks back-entry of a reading whose date nobody
  wrote down, and every pre-migration row.
- **A full datetime.** A gauge is read on a *day*; matches `inspected_at`'s
  date-only choice, and dodges timezone-of-capture ambiguity.

## Consequences

- Timecard transcription and offline capture become date-faithful; a
  reading taken Friday and synced Monday carries Friday.
- The latest-reading derivation moves from `created` to `read_at` — an
  additive field, but a *derivation refinement* worth a note in API.md
  (no contract-version bump: optional field, old behavior is the fallback).

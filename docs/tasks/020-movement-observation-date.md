# 020 — Add `movements.moved_at`: when the move actually happened

Status: DONE

## Context

`movements` is the source of truth, and its only timestamp is `created` —
server-set at insert. So a move logged offline on Friday and synced Monday is
stamped **Monday**. The ledger then says the asset was at the old job all
weekend, and every answer derived from move history inherits that error.

The other two append-only ledgers already solved this, for the same stated
reason:

- `inspections.inspected_at` — client-set, date-only UTC midnight (ADR 0014:
  "compliance math must survive offline queues and back-entry").
- `readings.read_at` — client-set, date-only UTC midnight, optional, falls back
  to `created` (ADR 0016, migration `1783468817`).

Movements never got the equivalent. It was found while drafting
[ADR 0022](../adr/0022-equipment-timecard-handoff-contract.md) (the
equipment-timecard handoff, accepted 2026-08-02) and recorded there as **open
issue 3**: because a timecard segment boundary is derived from movement
timestamps, an offline move synced late reports the asset at the wrong job for
the intervening days. ADR 0022 names this as the one open issue that should be
resolved **before any contract version is frozen**, because it corrupts derived
spans rather than merely weakening identity.

It also matters outside the contract. Offline capture is a headline feature
(ADR 0008), and a queued move can sit for hours or days in a dirt lot with no
signal — the exact case the ledger is supposed to handle well.

Read first: [ADR 0016](../adr/0016-reading-observation-date.md) (the direct
template — follow it closely), [ADR 0008](../adr/0008-offline-first-pwa.md)
(the queue this must survive), [ADR 0002](../adr/0002-append-only-ledger-derived-state.md)
(append-only, derived state), and [ADR 0022](../adr/0022-equipment-timecard-handoff-contract.md)
open issue 3.

## Scope

**Touch exactly these:**
- `pb_migrations/1783468826_movement_moved_at.js` — new migration (next free
  number; `1783468825_tag_code_nocase.js` is currently the highest).
- `pb_public/` — the movement-write paths, to stamp `moved_at` at capture, and
  the surfaces that display or order by move time. Movement writes currently
  live in `asset.html`, `material.html`, `scan.html`, `manifest.html`,
  `receiving.html`, `index.html`, and the replay path in `tn-sync.js`.
- `pb_public/sw.js` — bump `VERSION` (currently `v20`).
- `scripts/smoke_test.sh` — new assertions (see acceptance criteria).
- Docs: `docs/API.md`, `docs/DEVELOPER_GUIDE.md`, `USER_GUIDE.md`,
  `docs/current-state.md`, and a new ADR.

**Do NOT touch:**
- The movement **shape rule** or its create rules (migrations `1783468805`–
  `1783468807`). This task adds one optional field; it does not touch which of
  `asset`/`item`/`from_location`/`to_location` may be set.
- `assets.current_location` cache semantics, or the write-movement-then-PATCH
  ordering.
- `readings`, `inspections`, `manifests`, or the gang-box collections.
- `docs/contracts/timecard-handoff/` fixtures — regenerating them is a
  follow-up, not this task.

## Specification

1. **Migration `1783468826`.** Add `moved_at` to `movements`: `type: "date"`,
   **optional**. Follow `1783468817_reading_read_at.js` as the template,
   including the explanatory header comment and the working `down` migration
   that removes the field.

2. **Semantics — mirror `read_at` exactly.**
   - Client-set, **date-only at UTC midnight** (same storage convention as
     `read_at`, `inspected_at`, and the reservation dates).
   - **Optional.** Empty means unknown, and every derivation falls back to
     `created`. Pre-migration rows must keep working untouched.
   - `created` still records system-entry time and is never replaced.
   - Still append-only: `updateRule`/`deleteRule` stay superuser-only. A wrong
     `moved_at` is corrected by a new movement, never an edit.

3. **Stamp at capture, not at sync.** Every path that creates a movement sets
   `moved_at` to the capture day, so the value travels in the offline queue
   rather than being recomputed on replay. The existing pattern in
   `asset.html:1422` is exactly right:
   ```js
   moved_at: new Date().toISOString().slice(0, 10) + ' 00:00:00.000Z'
   ```
   Apply it to **all** movement-write paths listed in Scope, including
   `tn-sync.js` replay — a replayed movement must carry the day it was captured,
   not the day it synced.

4. **Derivation order shifts to `moved_at` with a `created` fallback**, the same
   way ADR 0016 moved readings to `sort=-read_at,-created`. Any surface that
   orders or buckets movements by time uses `-moved_at,-created`. Expected
   behavior:

   | Case | `moved_at` | `created` | Sorts/displays as |
   | --- | --- | --- | --- |
   | Online move | 2026-06-25 | 2026-06-25T07:41Z | 2026-06-25 |
   | Offline Fri, synced Mon | 2026-06-26 | 2026-06-29T14:02Z | **2026-06-26** |
   | Pre-migration row | empty | 2026-05-02T11:15Z | 2026-05-02 (fallback) |

5. **Display honestly.** Where a surface shows a move time and `moved_at`
   differs from `created`'s date, the UI shows the move day and indicates it was
   entered later (the pattern `asset.html` already uses for readings). Do not
   silently show only one of the two.

6. **A future-dated `moved_at` is accepted, not blocked** — consistent with how
   a lower-than-previous reading is accepted and flagged rather than rejected
   (ADR 0012). Flag it at render time if it is worth surfacing; never store a
   flag.

7. **New ADR** `docs/adr/0023-movement-observation-date.md`, house format
   (Title; Status/Date; Context; Decision; Alternatives rejected; Consequences),
   `Status: accepted`. It records why the third ledger gets what the other two
   already have, and closes ADR 0022's open issue 3. Note in ADR 0022 that the
   issue is resolved — do not rewrite its open-issue list, append the resolution.

## Acceptance criteria

- [ ] Migration `1783468826_movement_moved_at.js` exists, applies on a fresh DB,
      and its `down` removes the field cleanly.
- [ ] `moved_at` is optional; creating a movement **without** it still succeeds
      and every derived surface falls back to `created`.
- [ ] Every movement-write path in `pb_public/` stamps `moved_at` at capture,
      including `tn-sync.js` replay. Verify: queue a move offline, advance the
      clock / delay the sync, confirm the stored `moved_at` is the capture day
      and `created` is the sync day.
- [ ] Movement ordering uses `-moved_at,-created` wherever movements are sorted
      or bucketed by time; pre-migration rows (empty `moved_at`) still sort
      correctly among newer ones.
- [ ] Update and delete on `movements` remain refused for non-superusers
      (the append-only invariant is unchanged).
- [ ] Tests: new assertions in `scripts/smoke_test.sh` covering (a) a movement
      created with `moved_at` round-trips it, (b) one created without it
      succeeds, and (c) `moved_at` cannot be changed by a later update.
      Run: `scripts/smoke_test.sh` — must pass green.
- [ ] `VERSION` bumped in `pb_public/sw.js` (from `v20`).
- [ ] Docs updated per the docs-as-code checklist in `../../CLAUDE.md`:
      new ADR 0023, `docs/API.md` field list + the `readings`-style derivation
      note, `docs/DEVELOPER_GUIDE.md`, `USER_GUIDE.md` (plain-language: "the app
      records the day you actually made the move, even if it syncs later"),
      `docs/current-state.md`, and `AGENTS.md` mirrored if `CLAUDE.md` changed.
- [ ] ADR 0022's open issue 3 marked resolved with a pointer to ADR 0023.

## Guardrails

- **Additive only.** An optional field does not bump the API contract version —
  that is `docs/API.md`'s own rule, and ADR 0016 set the precedent for a
  derivation refinement recorded as a note rather than a version bump. Do not
  bump it.
- **Do not make `moved_at` required.** ADR 0016 rejected exactly that for
  `read_at`: it breaks back-entry and every pre-migration row. The same
  reasoning applies here and is not open for relitigation.
- **Do not use a full datetime.** Date-only at UTC midnight, matching
  `read_at` and `inspected_at`. A move is recorded on a *day*, and date-only
  dodges timezone-of-capture ambiguity. (Note the open tension: movements'
  `created` is a full timestamp and ADR 0022 open issue 5 leaves period/timezone
  bucketing unresolved. Storing date-only here is still the right call — do not
  try to settle issue 5 in this task.)
- **Do not store a derived flag** — no "was back-entered" boolean. Compare
  `moved_at` against `created` at render time (ADR 0002, ADR 0012).
- **Do not touch the movement shape rule or the ledger's append-only rules.**
- Format dates with `timeZone: 'UTC'` when displaying, or western timezones show
  the previous day — the standing convention in `CLAUDE.md`.
- Movements are created with pre-generated ids (`TNSync.genId()`) so offline
  replays stay idempotent — keep that pattern in any path you touch (ADR 0008).

## Definition of done

- [ ] Acceptance criteria all checked.
- [ ] `scripts/smoke_test.sh` green (required — this is a migration change).
- [ ] Documentation updated (ADR 0023 / API.md / DEVELOPER_GUIDE / USER_GUIDE /
      current-state), and `AGENTS.md` mirrored if `CLAUDE.md` changed.
- [ ] `Status:` above set to `DONE`.
- [ ] Committed (author: maintainer only, **no `Co-Authored-By` trailer**) with a
      message describing what changed. Then stop and show the maintainer.

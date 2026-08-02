# ADR 0022 — Equipment-timecard handoff contract (producer side)

**Status:** accepted · **Date:** 2026-08-02

> **Accepted on the producer side.** This settles the *shape* of the handoff —
> promotion path step 4 in
> [ecosystem-contracts.md](../ecosystem-contracts.md), for this repository only.
> It is **not** a published contract: no version is frozen, and nothing here
> changes code, migrations, or endpoints. Still outstanding — a matching
> accepted ADR in `bindery-trenchnote` (the consumer half of step 4), then a
> published versioned contract with compatibility tests (steps 5–6). **Open
> issue 3 below has since been resolved** by
> [ADR 0023](0023-movement-observation-date.md) (`movements.moved_at`), which
> was the stated gate on freezing a version. Open issues 1, 2, 4 and 5 remain,
> and are survivable as documented caveats.

## Context

The division running TrenchNote hand-maintains a **weekly equipment timecard**:
six PMs, every Friday, reconstructing which job number each owned asset sat at
that week, with arrival/removal dates and month-end hour-meter / odometer
readings. Accounting derives equipment billing from it. That is incident 2 in
[BACKLOG.md](../BACKLOG.md), and ADR 0012 landed the core data it needs —
`locations.job_code`, `items.meter`, `assets.assigned_to`, and the append-only
`readings` ledger.

On 2026-07-21 the maintainer promoted this to TrenchNote's **first real
ecosystem contract** ([ROADMAP.md](../../ROADMAP.md), "Decided"). Producer:
TrenchNote, exposing `movements` and `readings`. Consumer: `bindery-trenchnote`,
the private premium sidecar, which composes the timecard and applies rates.

This split is the whole point. TrenchNote already holds the raw material as
source-of-truth data and is *better* at it than the spreadsheet — the 2020
timecard evidence shows week 1 filled and weeks 2–4 blank, the Friday ritual
dying mid-month, a failure a ledger-derived report cannot have. But BACKLOG
item 7 and ADR 0015 both draw the same wall: the core exposes clean append-only
data and **never computes billing**. This contract is the shape of the handoff
across that wall.

Read alongside: [ADR 0011](0011-core-premium-extension-boundary.md) (the
sidecar boundary), [ADR 0012](0012-timecard-data-capture.md) (what data
exists), [ADR 0015](0015-rental-dates-in-core.md) (rates are premium),
[ADR 0016](0016-reading-observation-date.md) (observation dates).

## Decision

Propose a **handoff manifest**, not a lifecycle event stream.

The `ecosystem-contracts.md` vocabulary offers both. An event announces that a
fact occurred; a manifest transfers "a bounded, reviewable package." A billing
period is bounded and reviewable by construction — a PM reconciles a week, an
accountant reconciles a month — and it must survive being regenerated when a
late offline sync changes what the period contains. That is a manifest.

`handoff_type` is **`equipment.timecard_period`** — one bounded use case, not a
universal work-item model.

### Shape, mapped onto the existing vocabulary

| Manifest field | Source of the value |
| --- | --- |
| `manifest_public_id` | Deterministic: `{issuer}:{instance}:{handoff_type}:{period}` |
| `manifest_version` | Contract version, `equipment-timecard-handoff/1` |
| `revision` | Integer, incremented when the same period is regenerated |
| `producer` | Issuer, instance, product + PocketBase versions (ADR 0011 ties REST behavior to a tested PocketBase version) |
| `produced_at` | Assembly time |
| `period` | `start` / `end`, date-only UTC midnight, end inclusive |
| `assets[]` | One entry per owned asset with activity in the period |
| `assets[].subject_ref` | **External reference** — `public_id` is `tag_code` |
| `assets[].segments[]` | Derived from `movements`: where it sat, and for how long |
| `assets[].segments[].project_ref` | **Project reference** — `project_code` is the location's `job_code` |
| `assets[].readings[]` | Derived from `readings`, ordered `-read_at,-created` |
| `evidence[]` | **Evidence envelopes** for reading photos, referenced by id |
| `summary` | Human reconciliation counts |
| `integrity` | Present, null — hashing rules are unresolved upstream |

Two deviations from the vocabulary tables, both deliberate:

- **`project_ref` sits on the segment, not the manifest.** The manifest table
  puts one `project_ref` at the top level. A timecard period spans many jobs by
  definition — that is the entire fractional-split problem — so a single
  top-level project reference cannot express it. The manifest is scoped to a
  *period and an instance*; project scope belongs to each segment.
- **`revision` is added.** The vocabulary has no concept of regenerating a
  package. TrenchNote's offline queue (ADR 0008) guarantees that a period's
  contents can change days after it closed, so the contract needs a way to say
  "same logical package, newer truth." Consumers replace by
  `(manifest_public_id, revision)`; re-importing the same pair is a no-op.

### Everything is derived; nothing is added

A **segment** is one continuous stay: the asset arrived at a location via one
movement and left via the next movement that names it. `arrived_before_period`
marks a stay that started earlier; `present_at_period_end` marks one that had
not ended. The current job is the location's `job_code` (ADR 0012), never
stored on the asset. Latest reading is the newest `readings` record, ordered by
`read_at` falling back to `created` (ADR 0016) — there is no latest-reading
column, and this contract does not propose one.

No new collection, field, endpoint, or stored flag is proposed. Where the
derivation is weak, that weakness is an open issue below, not a schema change.

### What the contract deliberately does not carry

- **No rates, costs, amounts, or currency.** Confirmed against ADR 0015: dates
  and readings are non-commercial facts about physical things and live in core;
  the money does not. The consumer holds the rate table.
- **No fractional job-splits.** The manifest reports *spans* — this asset was at
  6054.2 from here to here. It does not compute `0.25/0.25/0.25/0.25`, day
  fractions, or allocation percentages. Accounting owns the split (BACKLOG item
  7, "explicitly not"), and computing it here would put the billing logic in the
  producer with the rates one field away.
- **No usage state.** The 2020 timecards record `X` / `IDLE` / `STORED` /
  `BROKE DOWN` per week. TrenchNote does not track usage and must not infer it;
  a readings delta can at most hint that a machine ran. There is no `usage`
  field, deliberately, and a consumer that wants one must get it from a human.
- **No personal data beyond what the ledger already holds** — `moved_by`,
  `recorded_by`, and `assigned_to` are free-text names crews typed, carried
  verbatim and marked as unverified assurance.

### Versioning

Declares major version 1. Additive optional fields are safe and older consumers
ignore them. A new major version is required for removed fields, newly required
fields, identifier-semantics changes, enum meaning changes, or an authority
change. This ADR does **not** bump the [API.md](../API.md) contract version —
the REST surface is untouched.

### Fixtures

[`../contracts/timecard-handoff/`](../contracts/timecard-handoff/) — fictional
but realistic, using real fleet-number conventions (ADR 0010, BACKLOG item 8).

- **`asset-split-across-two-jobs.json`** — forklift `FL-16` across week
  2026-W26: at Riverbend WWTP (`6054.2`) from before the period, moved to
  Northgate Lift Station (`6119.1`) on the 25th, still there at period end. Two
  segments, one shared movement (the departure of segment 0 is the arrival of
  segment 1), no split computed.
- **`month-end-meter-reading.json`** — pickup `P-138` for June 2026: one
  continuous segment, three odometer readings including a month-end walkdown
  captured offline on the 30th and synced on the 1st (`read_at` preserves the
  observation day, `created` does not), a mid-month reading flagged
  `lower_than_previous`, and an evidence envelope for the gauge photo. It is
  `revision: 2`, regenerated after a late sync.

## Open issues

These are named, not solved. Each is a decision for its own ADR.

1. **No project entity.** Only `locations.job_code` carries job context, and it
   is optional, non-unique (two locations can share one), and **mutable** — with
   no history. Because a segment's project is derived from the location's
   `job_code` *as it reads today*, editing a job code silently rewrites derived
   history for every past period. For a billing-adjacent payload that is a real
   correctness problem, not a cosmetic one. The contract therefore sets
   `project_public_id: null` and carries `project_code` as a **label for
   reconciliation, never as identity** — exactly the caveat
   `ecosystem-contracts.md` states. Cross-links BACKLOG item 4, whose ecosystem
   note already reserves room for a stable project reference.
2. **No stable public IDs.** Only `assets.tag_code` qualifies (stable, printed,
   never recycled — ADR 0010), and it is the `public_id` for assets. Movements,
   readings, and locations have only PocketBase record ids, which are
   instance-scoped and **not stable across export/import or a database
   restore** — failing the contract's own requirement. They are carried as
   `local_record_id`, explicitly labelled, and never used as cross-product
   identity. Replay safety rests on `manifest_public_id` + `revision` instead.
   Fixing this properly means minting public ids on those collections: a
   migration, an ADR, and a decision this proposal does not make.
3. **~~Movements have no observation date.~~ RESOLVED 2026-08-02 by
   [ADR 0023](0023-movement-observation-date.md)** — `movements.moved_at`
   (migration `1783468826`) is the client-set observation date this issue asked
   for, and segment boundaries now derive from the day a move happened. The
   original statement is kept below for the record. The fixtures in
   `../contracts/timecard-handoff/` still carry full timestamps in
   `arrived_at`/`departed_at` and are due a regeneration when the contract is
   next revised.

   `readings` got `read_at` (ADR 0016)
   and `inspections` got `inspected_at` (ADR 0014), both client-set, both for
   the same stated reason: the math must survive offline queues and back-entry.
   `movements` never got the equivalent — its only timestamp is `created`,
   server-set at insert. So a move logged offline on Friday and synced Monday
   produces a **segment boundary on Monday**, and the asset is reported at the
   wrong job for the weekend. This is the single largest accuracy gap in the
   proposal and it affects the ledger the whole contract is built on. Naming it
   here; the fix is a third ADR in the `read_at` / `inspected_at` family.
4. **Evidence authorization is unresolved.** `source_url` points at
   `/api/files/readings/{id}/{filename}`, which requires the consumer's own
   service-account token (ADR 0011). Expiry, retention, redaction, and whether
   copied evidence is permitted at all are open upstream in
   `ecosystem-contracts.md`. `sha256` is omitted until hashing rules are
   accepted; `integrity` is present and null for the same reason.
5. **Period boundaries and timezones.** Dates are date-only at UTC midnight per
   the house convention, but movements carry full UTC timestamps. A move at
   19:00 local on a Friday in a western timezone lands on Saturday in UTC. The
   contract currently passes through UTC and lets the consumer bucket; whether
   the producer should instead carry an instance timezone is unresolved.

## Alternatives rejected

- **A lifecycle event stream** (`logistics.asset_moved` + `logistics.reading_recorded`).
  Rejected for the *first* contract. Events are the better long-term shape — they
  are incremental, and the sidecar could subscribe over SSE — but they push all
  period assembly onto the consumer, which is exactly where the fractional-split
  and late-sync logic would then live, unreviewable. A manifest is a package a
  human can open and check against a spreadsheet the division already trusts.
  Events remain the natural v2.
- **Carrying computed day-fractions or job-splits.** Rejected on the wall. It is
  one field away from rates, and BACKLOG item 7 names it explicitly.
- **Proposing a `job_code` history table** to fix open issue 1. Rejected as out
  of scope by the task's own guardrail: gaps get named, not designed around by
  adding storage. It is also a genuine schema decision deserving its own ADR.
- **Using PocketBase record ids as `public_id`.** Rejected — they fail the
  stability requirement the contract itself declares, and blessing them now
  would make the eventual real public ids a breaking change.
- **A private endpoint or export tuned for the sidecar.** Rejected on principle
  by ADR 0011: the door premium uses is the door everyone gets. This manifest is
  assemblable by any authenticated API client from documented collections.

## Consequences

- **Nothing ships.** No migration, no endpoint, no `sw.js` change, no API
  contract bump. Acceptance settles a shape; the core is otherwise unaffected.
- The contract is **assemblable today** by any client from `movements`,
  `readings`, `assets`, `locations`, and `items` — but three of the five open
  issues above (1, 2, 3) meant a v1 frozen at proposal time would carry known
  accuracy caveats. Open issue 3, the blocking one, is resolved by
  [ADR 0023](0023-movement-observation-date.md); issues 1 and 2 remain
  unscheduled and are survivable as documented caveats.
- This ADR obliges a matching accepted ADR in `bindery-trenchnote` (the consumer
  half of promotion path step 4) before either side implements.
- The fixtures here become the seed of the compatibility test suite that travels
  with the published contract (step 5).

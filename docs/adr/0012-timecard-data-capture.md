# ADR 0012 — Timecard data capture: job codes, meter readings, custodianship

**Status:** accepted · **Date:** 2026-07-10

## Context

Real-world validation from the division running TrenchNote, same week:

1. A PM email thread about laborers taking scaffolding off a site
   unannounced — the exact chaos the movements ledger exists to prevent,
   except the PM found out days later instead of the moment it happened.
2. The division's **"Weekly Equipment Timecard"** spreadsheet: every
   Friday, each PM manually reconstructs which job number every piece of
   owned equipment sat at that week, plus hour-meter/odometer readings at
   month-end and whenever equipment leaves a site. The office uses it to
   **bill equipment time to jobs.**

The ledger already derives the location history automatically — better
than the spreadsheet does, because it's captured at scan time instead of
reconstructed on Friday. What the core cannot yet answer:

- **Which job number** a location's equipment time is billed to.
- **Meter readings** — the hours/odometer numbers the billing rates key on.
- **Custodianship** — trucks and vehicles are assigned to a person and
  rarely move between jobs like shared tools do; "whose is it" is a
  different question from "where is it".
- **Immediate notification** when something scans OFF a site (the
  scaffolding thread) — the losing site's PM is the one who gets
  surprised; the receiving site initiated the scan.

A future premium sidecar (trenchnote-lookahead, per the ADR 0011 boundary)
will generate the timecard spreadsheet from this data. The generator is
premium; per ADR 0011, **the data it needs lands in core first**, AGPL,
migrated, documented, available to every API client equally.

## Decision

Two migrations (`1783468809`, `1783468810`):

### Fields on existing collections

- **`locations.job_code`** (text, optional) — the accounting job number
  ("6054.2"). Text, not number: accounting formats vary. Current job for a
  piece of equipment is **derived**: its current location's `job_code`.
- **`locations.notify_email`** (email, optional) — the PM/superintendent
  to email the moment a movement leaves this location (the hook is a
  separate concern; this ADR only adds the fact).
- **`items.meter`** (select `hours` | `odometer`, optional, empty = no
  meter) — whether this *kind* of thing has a meter. On the catalog, not
  the asset: every 19' scissor lift has an hour meter, so it's flagged
  once, and the reading prompt knows what to call itself ("Hour meter"
  vs "Odometer") with zero extra taps at the scan moment.
- **`assets.assigned_to`** (text, optional) — custodianship, per physical
  unit. Free text like `movements.moved_by`: crews don't have accounts.

### New collection: `readings` — an append-only ledger, like movements

`asset` (relation, required) · `value` (number, required) · `reading_type`
(`hours` | `odometer`, required — copied from `items.meter` at capture
time so each record stays self-contained if the catalog is re-flagged) ·
`recorded_by` (text) · `photo` (file, the gauge). Timestamp is the
`created` autodate, same as movements. Auth-required rules from day one;
`updateRule`/`deleteRule` are `null`.

- **Append-only** because these numbers end up on invoices. Meters get
  misread and typo'd; a correction is a new reading, and the history is
  what settles the dispute.
- **A reading lower than its predecessor is accepted, never blocked** —
  meters get replaced — but **flagged at render time** by comparing
  neighbors. The flag is derived, not stored: a stored flag could disagree
  with the records it summarizes (e.g. when offline queues sync out of
  order).
- **No `latest_reading` on the asset and no `current_job` anywhere.**
  Latest reading = newest readings record; current job = current
  location's `job_code`. Same principle as `assets.current_location`
  being a cache and bulk stock being summed: stored copies drift.

### Free-tier placement

Off-site notification (the `notify_email` consumer) stays in **free
core**: it's field-adjacent visibility — the digital equivalent of seeing
the truck pull away — not office intelligence. The timecard *generator*
(XLSX, rate tables, month-end interpolation) is the premium sidecar. The
line from ADR 0011 holds: the ledger is free, insight about the ledger is
paid.

## Alternatives considered

- **Store readings as fields on the asset record** (`last_reading`,
  `last_reading_date`) — rejected. History matters for billing disputes,
  meters get misread, and an overwritable pair of columns silently
  destroys the previous value exactly when you need it (the typo you're
  correcting). It's the same mistake as storing stock-on-hand.
- **`has_meter` boolean on assets** — rejected in favor of the `meter`
  select on items. Per-asset flags mean flagging six identical scissor
  lifts six times, and a boolean still leaves the capture UI guessing
  whether to say "hours" or "miles". Whether a thing has a meter is a
  property of what it *is* — catalog data.
- **Inferring "has a meter" from a prior reading** — rejected: bootstrap
  problem (the first reading is never prompted for, because there's no
  prior reading), plus an extra query on every scan just to decide whether
  to render one optional field.
- **A required reading on every move** — rejected without much thought:
  it violates the ethos. The scan-and-move flow is never blocked or
  slowed; the reading is one optional field, skippable with zero friction.

## Consequences

- The API contract (docs/API.md) gains a sixth collection and four fields —
  **additive**, so contract v1 stands; the shapes are documented there.
- Month-end walkdowns get a standalone "record a reading" action on the
  asset page — a reading does not require a movement.
- What the core still cannot answer for the timecard (rates, per-job
  splits within a week, idle/no-charge status) is deliberately left to
  the premium generator's design discussion — see the session notes, not
  this ADR.

# ADR 0019 — Damage and condition reports as append-only evidence

**Status:** accepted · **Date:** 2026-07-12

## Context

Damage is usually found by the next person who touches an asset. Without a
photo tied to the asset and a durable timestamp, the discovery becomes a phone
call or memory: nobody can establish whether the prior custodian handed over a
damaged tool, and a rental yard's return inspection becomes the only evidence
in an invoice dispute.

The scan page is already the field touchpoint for identity, location,
movements, readings, and inspections. Condition evidence belongs there, but it
must preserve TrenchNote's established rules: append facts, derive status, work
offline, and do not grow a repair-management system.

## Decision

### Two append-only collections

`condition_reports` records the observation: `asset` (relation), `report_type`
(`damage` | `wear` | `condition_note`), `description`, one **required** `photo`,
`reported_by`, and server-set `created`.

`condition_resolutions` records the outcome: `report` (relation), `resolution`
(`repaired` | `accepted_as_is` | `disposed` | `returned_to_vendor`), `note`,
`resolved_by`, and server-set `created`.

Both collections require authentication for reads and creates. Updates and
deletes are unavailable to ordinary API clients. A correction is another
report or resolution, so the original observation and every later human action
remain visible. PocketBase relation fields use the project's existing names
`asset` and `report`; their values are the asset/report IDs described in the
domain model.

The report photo is required at the schema boundary, not merely nagged for in
the UI. A text-only damage note does not provide the dispute evidence this
module exists to preserve. This differs deliberately from inspection failures,
where blocking a record could prevent someone from pulling unsafe gear from
service.

### Damage is derived

An asset is **DAMAGED** when at least one `condition_reports` row with
`report_type = damage` has no related `condition_resolutions` row. The badge is
never written to `assets` and no report has an `open` field. Wear and
`condition_note` records remain history but do not produce the badge.

Multiple resolutions for one report are legal. Two offline phones may both
record true actions before either sees the other's row; a uniqueness rule would
reject one fact. For the badge, any resolution closes the report. The history
still shows the race for a human to interpret.

### Timestamp and offline order

`created` is the authoritative timestamp, matching movement arrival-order
truth in ADR 0008. First-party clients pre-generate record IDs and queue the
required photo in IndexedDB. FIFO replay preserves this phone's report/move
order, while the server timestamp records when evidence entered the shared
ledger. A client-supplied capture timestamp is not added: it would be easy to
misstate and would create a second ordering rule solely for this module.

### Field UI and priority

The asset scan page owns a photo-first report flow and the resolution action.
When an asset is rented, it also shows a gentle link to photograph condition at
delivery and before return. The dashboard lists unresolved damage oldest first.
On the asset page, an inspection RED / DO NOT USE verdict remains above the
DAMAGED badge: safety status outranks condition evidence.

### Scope fence

This module records an observation and an outcome. It does not create repair
work orders, assign mechanics, schedule maintenance, track parts or labor,
approve return to service, or calculate costs. A resolution is a human fact,
not a workflow state machine.

## Alternatives rejected

- **A mutable condition/status field on `assets`.** It would erase evidence,
  drift during offline races, and fail to answer who reported or resolved what.
- **An `open` or `damaged` boolean on a report.** Redundant with the resolution
  ledger and able to disagree with it.
- **Condition fields on movements.** Damage can be found without moving an
  asset, while multiple photos at rental delivery are distinct observations.
- **Optional photo.** Text alone does not meet the dispute-evidence purpose.
- **Repair work orders or a maintenance module.** Assignment, scheduling,
  labor, parts, costs, and maintenance planning cross the product boundary.

## Consequences

- Two additive collections extend API contract v1 without changing existing
  record shapes.
- Photo storage and backups grow with every report; each report is bounded to
  one deliberately attached image.
- Reads do a small set difference (damage reports minus resolution relations)
  to render status. At TrenchNote scale this is simpler and safer than a stored
  cache.
- A resolved report stays in both ledgers forever, preserving the evidence that
  a problem existed and the human statement of how it ended.

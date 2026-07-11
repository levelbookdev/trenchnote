# ADR 0015 — Rental on/off dates belong in core; rates stay premium

**Status:** accepted · **Date:** 2026-07-10

## Context

A rented asset already carries `vendor` and `po_number` in the core
`assets` record (ADR: rentals are not a special case — just an owned asset
with those fields set). But its **dates** — on-rent and off-rent — have
lived only in the premium sidecar's `rental-terms.json`, keyed by
`tag_code` (ADR 0006). That was the right call for *money*: rates are
commercial data the AGPL core must not carry (ADR 0011, "the ledger is
free, insight about the ledger is paid").

Dates are not money. "This lift comes off rent July 15" is a fact about the
physical thing, the same category as its vendor and PO. Keeping it
premium-only means the office can't see it in the field app, every
integration must re-key it, and the sidecar's terms file has to carry data
that isn't commercial.

## Decision

Two optional `date` fields on `assets` (migration `1783468816`):
`on_rent_date`, `off_rent_date`. Empty on owned assets. Stored date-only at
UTC midnight, matching the reservations date convention.

- **Dates in core, rates in premium.** The line is commercial-vs-not, and
  it stays exactly where ADR 0011 drew it. `rental_rate` / `rate_period`
  remain in Lookahead's `rental-terms.json`; the dates move out of it.
- **Additive to API contract v1.** New optional fields don't bump the
  contract version (docs/API.md's own rule), but this ADR + an API.md
  field-list update record the grown surface.
- **Set in the admin UI, displayed in the field app.** Like vendor/PO,
  these are office-entered in the PocketBase admin UI. asset.html *shows*
  the off-rent date on a rented asset (a foreman scanning a lift sees when
  it's due back) but does not add a field-edit form — asset.html is the
  crew scan surface, and an office-edit affordance there is deliberate
  future scope, not this change.
- **Premium prefers core, falls back to the file.** Lookahead reads
  `off_rent_date`/`on_rent_date` from the asset when present and falls back
  to `rental-terms.json` when absent — no flag day; existing terms files
  keep working, and the file can shrink to rates-only over time (the audit
  F5 note anticipated exactly this).

## Alternatives rejected

- **A core `rental_terms` collection** (dates + a join). Rejected: dates
  belong to the asset, so a separate table is a needless join — and a
  "rental terms" table in core invites the next PR to add `rate`, walking
  the commercial line ADR 0011 exists to hold. Two plain fields keep the
  boundary obvious.
- **Leaving dates premium-only.** Rejected: it forces every client to
  re-key a non-commercial fact and hides useful field info (off-rent
  countdown) from the crews scanning the asset.

## Consequences

- The field app can show "off rent in N days" on a rented asset; a future
  small addition could flag overdue rentals in core itself, though the
  burn-cost analysis (which needs rates) stays premium.
- `assets` gains two nullable columns; owned assets are unaffected.
- Lookahead gets a follow-up change (separate repo) to prefer the core
  dates. Until then it keeps using its terms file — nothing breaks.

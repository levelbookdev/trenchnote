# ADR 0018 — `items.item_code`: a reference number for bulk (and cataloged) items

**Status:** accepted · **Date:** 2026-07-11

(ADR 0017 — a `virtual` location type for terminal destinations — was
proposed alongside this and **deferred**: the ADR 0005 "make an *Installed —
X* location and move there" convention already works, and the ethos argues
against schema for a cosmetic dashboard win. Revisit only if terminal-
location clutter becomes a real field annoyance.)

## Context

Assets carry `tag_code` — unique, human-readable, the thing the QR encodes.
**Bulk items carried no code anywhere.** The division numbers bulk materials
the same way it numbers vehicles ("Misc-66" K-rail, "P-138" truck), but a
bulk item has no asset to hang a code on, so the June seed had to smuggle
"Misc-66" inside the item's `description` — unstructured and unsearchable.

## Decision

Add `item_code` to `items`: `text`, **optional, non-unique** (migration
`1783468818`). It's the office's catalog/reference number for a *kind* of
thing — most meaningful for bulk items (which otherwise carry no code), and
fine as a manufacturer/part number on unique items too. Displayed on
material.html; set office-side in the admin UI like other catalog fields.

## Alternatives rejected

- **Keep using `description`.** Unstructured, unsearchable, and it's a
  distinct field the office actually keys — conflating the two loses both.
- **A unique index.** PocketBase stores empty text as `""`, not `NULL`, so a
  unique index would reject the *second* item left blank. Enforcing
  uniqueness is a separate opt-in decision (partial index + de-dup pass) for
  if the office ever wants it.
- **A separate codes table.** Overkill for one string on the catalog.

## Consequences

- Bulk items get a real, searchable office number; "Misc-66" moves out of
  `description` into its own field.
- Additive to API contract v1 (new optional field, no version bump).
- Deferred sub-decision: whether to later enforce uniqueness.

# ADR 0010 — QR URL and tag-code format

**Status:** accepted · **Date:** 2026-07-09 (documents the format as shipped)
**Provenance:** ported 2026-07-09 from `trenchnote-alt` (ADR 0004 there);
renumbered because this repo's 0004 is the auth ADR. Content unchanged
except cross-references.

## Context

Every tracked asset gets a printed QR label taped to it. Labels live on
equipment for years, in mud, and reprinting a whole division's worth is a
real afternoon of work — so whatever the QR encodes is effectively
permanent. This ADR records the format so that any future change is
recognized for what it is: a breaking change to physical objects in the
field, not a code refactor.

## Decision

- **The QR encodes a plain URL:** `{Base URL}/asset.html?code={tag_code}`.
  A URL is the one thing every phone camera opens natively — no app, no
  special QR reader (this is hard constraint #1). The in-app scanner
  (ADR 0009) reads the same URL format; it is a convenience layer, not a
  different encoding.
- **Assets are looked up by `tag_code`, not by database record id.**
  `tag_code` is a short human-assigned code (3–5 characters, e.g. `A001`)
  with a unique index in the `assets` collection. Because the label carries
  the *code* rather than an internal id, the database can be rebuilt,
  restored, or re-imported and every printed label keeps working — only the
  `tag_code` values must be preserved.
- **The code is also printed in plain text under the QR** as the mud-proof
  fallback: too scratched to scan, still readable by eye and typable.
- **Short codes + error correction level H.** Level H lets ~30% of the
  pattern be damaged and still scan; it costs QR density, which is why tag
  codes stay short — a 4-character code at level H is still a coarse,
  scratch-tolerant grid.
- **The Base URL is chosen at print time** on labels.html (LAN IP for a
  trailer deployment, a real domain later). The pages themselves never
  hardcode a host — but the printed labels necessarily do.

## Alternatives rejected

- **Encoding the PocketBase record id** (`asset.html?id=xyz123`): ids are
  opaque (no human fallback to print) and are regenerated on re-import, so
  a database rebuild would orphan every printed label.
- **A short-link/redirect service** (`tn.example/A001`): survives moving
  the app to a new address, but adds a second moving part that must never
  die — violating single-binary simplicity for a problem reprinting solves.
- **Encoding asset data in the QR itself** (name, location, vCard-style):
  stale the moment the thing moves. The QR must point at the live record,
  not carry a snapshot.

## Consequences

- Renaming `asset.html`, changing the `code` query parameter, or changing
  what `tag_code` means invalidates every printed label. Per the standing
  orders in CLAUDE.md, any such change must be flagged loudly and needs the
  maintainer's explicit confirmation.
- Moving the server (LAN IP → domain) also invalidates labels — a known,
  accepted cost, documented in DEPLOY.md ("don't laminate 200 labels before
  choosing where TrenchNote lives"). A future custom-domain setup should
  happen *before* mass printing.
- Tag codes must stay unique forever; retiring an asset should retire its
  code rather than recycling it onto new gear, or old labels in the mud
  start pointing at the wrong machine.
- The URL format and `tag_code` semantics are part of the public API
  contract ([docs/API.md](../API.md), ADR 0011): premium and third-party
  tools may rely on them exactly as printed labels do.

## Addendum (2026-07-21) — fleet numbers and case handling

Adopted as the first production assets were catalogued.

- **Fleet numbers ARE the tag code.** For equipment that already carries a
  stenciled company asset number (`P-138`, `FL-16`, `SC-50`, `MISC-37`,
  `T-127A`), `tag_code` is that number verbatim, uppercase. Crews already speak
  these numbers; a parallel invented ID would fight a decade of stenciled paint.
  Invented short codes (`A001` style) stay the convention only for untagged
  small tools and future unassigned-tag pools (docs/BACKLOG.md items 8 and 1).
  No schema change was needed — `tag_code` is free text; hyphens, mixed length,
  and trailing letters were already accepted, and the longest realistic code
  still encodes to a coarse QR version 6 (41×41) at level H.
- **Codes are uppercase-canonical and matched case-insensitively.** Two
  independent changes make this true, because they cover different halves:
  - *Uniqueness* — the unique index gained `COLLATE NOCASE` (migration
    `1783468825`), so `P-138` and `p-138` can never be saved as two assets.
  - *Lookup* — the index change does **not** make PocketBase's `=` filter
    case-insensitive (the filter compares the column, BINARY, not the index),
    so `asset.html` and `scan.html` normalize a scanned or typed code to
    uppercase before the lookup. Any new tag-lookup path must do the same.
  The net effect: a label read or typed in any case resolves to the one asset,
  and the stored/printed form stays uppercase.

# ADR 0023 — `movements.moved_at`: when the move actually happened

**Status:** accepted · **Date:** 2026-08-02

## Context

`movements` is the source of truth for the whole product, and its only
timestamp was `created` — server-set at insert. So a move logged offline on
Friday and synced on Monday was stamped **Monday**. The ledger then said the
asset sat at its old location all weekend, and every derived answer inherited
that: the asset's history, "days here", the dashboard's recently-moved feed,
the receiving log's chronology.

This is not a corner case. Offline-first is a headline feature (ADR 0008) —
the app is built for dirt lots with no signal, and a queued move can sit for
hours or days before it syncs. The ledger was recording the day the phone found
a tower, not the day the forklift moved.

The other two append-only ledgers already solved this, for the same reason,
before this one did:

- `inspections.inspected_at` (ADR 0014) — client-set, date-only UTC midnight,
  because "compliance math must survive offline queues and back-entry."
- `readings.read_at` (ADR 0016, migration `1783468817`) — same shape, optional,
  falling back to `created`, because meter numbers end up on invoices and the
  month they belong to is not cosmetic.

ADR 0016 put the principle plainly: "`readings` is the second append-only
ledger; inspections is the third. The second should get what the third already
has." The same sentence applies here, to the first.

It surfaced concretely while drafting [ADR 0022](0022-equipment-timecard-handoff-contract.md),
the equipment-timecard handoff, and was recorded there as **open issue 3**:
because a timecard segment boundary is derived from movement timestamps, a
late-synced move reports the asset at the wrong job — and those job numbers
feed equipment billing. ADR 0022 named it as the one open issue that should be
resolved before any contract version is frozen, because it corrupts derived
spans rather than merely weakening identity.

## Decision

Add `moved_at` to `movements`: `date`, **client-set, date-only at UTC midnight,
optional** (migration `1783468826`). Empty means unknown, and every derivation
falls back to `created`. `created` still records system-entry time.

This mirrors `read_at` deliberately and exactly — the same shape, the same
fallback, the same reasoning. A third variation on "when did this happen" would
be a maintenance burden for no gain.

- **Stamped at capture, never at replay.** Every movement body is built once,
  with a pre-generated id, so the identical record can be POSTed now or
  replayed from the offline queue (ADR 0008). `moved_at` is set when that body
  is built, so it travels through IndexedDB with the move instead of being
  recomputed on sync. `TNSync.enqueue` backfills it defensively for any caller
  that did not; `manifest.html` stamps explicitly because its batch goes through
  `enqueueBatch`, which has no per-movement backfill.
- **One shared helper.** `TNSync.today()` produces the stamp, beside
  `TNSync.genId()`. Seven pages build movements; a duplicated date expression
  would drift.
- **Derivation order becomes `-moved_at,-created`**, the same refinement ADR
  0016 made for readings. The `created` tiebreak is load-bearing rather than
  decorative: `moved_at` is date-only, so every move made on one day carries an
  identical stamp, and without the tiebreak an A→B then B→C on the same
  afternoon would lose its order.
- **Still append-only.** `updateRule`/`deleteRule` stay superuser-only. A wrong
  `moved_at` is corrected with a new movement, never an edit — these dates reach
  equipment invoices by way of ADR 0022.
- **Container-membership windowing keeps using `created`.** `container_events`
  carries no observation date, so comparing a date-only `moved_at` against an
  event's full timestamp would misjudge which side of an add/remove a move fell
  on. Arrival order stays the authority there (ADR 0008), exactly as before.
  `tn-containers.js` therefore carries two clocks on purpose: `when` orders what
  a human reads, `created` decides membership and breaks ties.
- **Display shows both when they differ.** A move captured offline and landed
  later reads as "Jun 26 · entered Jun 29". Showing only one of the two days
  would hide the gap a PM reconciling a timecard needs to see.
- **A future-dated `moved_at` is accepted**, consistent with a lower-than-
  previous reading being accepted and flagged rather than blocked (ADR 0012).
  Nothing about it is stored as a flag.

## Alternatives rejected

- **Making `moved_at` required.** Rejected for the same two reasons ADR 0016
  rejected it for `read_at`: it breaks back-entry of a move whose date nobody
  wrote down, and it invalidates every pre-migration row. Optional with a
  `created` fallback keeps the whole existing ledger readable.
- **A full datetime instead of a date.** Rejected to match `read_at` and
  `inspected_at`. A move is recorded on a *day*, and date-only sidesteps
  timezone-of-capture ambiguity for a value the client supplies. The cost is
  real and accepted: intra-day ordering now depends on the `created` tiebreak.
- **Back-filling `moved_at` on existing rows from `created`.** Rejected — it
  would invent an observation date nobody observed, on an append-only ledger, and
  make a guess indistinguishable from a fact. Empty honestly means unknown.
- **Deriving the move date server-side from the sync payload** (e.g. a hook
  reading the queue's `queuedAt`). Rejected: it puts client-supplied time
  laundering inside the server, and `queuedAt` is only present for moves that
  happened to go offline. The client already knows the capture date; it should
  just say so.
- **A stored "was back-entered" flag.** Rejected per ADR 0002/0012 — compare
  `moved_at` against `created` at render time. A stored flag can disagree with
  the records it summarizes.

## Consequences

- **ADR 0022's open issue 3 is resolved.** The timecard handoff can derive
  segment boundaries from the day a move happened. Its fixtures still carry
  full timestamps in `arrived_at`/`departed_at` and would be regenerated when
  the contract is next revised — a follow-up, not part of this change.
- **Additive, so contract v1 stands.** An optional field does not bump the API
  contract version (docs/API.md's own rule); ADR 0016 set the precedent for
  recording a derivation refinement as a note instead. `docs/API.md` gains the
  field and the `sort=-moved_at,-created` guidance.
- **API clients should mirror the new sort.** A consumer still ordering by
  `-created` alone gets sync-order, not move-order — the same caveat ADR 0016
  left for readings.
- Two `fmtDate` helpers (`material.html`, `receiving.html`) lacked
  `timeZone: 'UTC'`. Harmless while they only ever received full timestamps;
  a latent previous-day bug in western zones the moment they receive a
  midnight-UTC value. Fixed as part of this change.
- **Open issue 5 of ADR 0022 is untouched.** Movements' `created` is a full
  timestamp while `moved_at` is date-only, and how a period buckets a move made
  at 19:00 local on a Friday in a western timezone is still unresolved. Storing
  date-only here is the right call regardless; the bucketing question belongs to
  the contract, not the field.

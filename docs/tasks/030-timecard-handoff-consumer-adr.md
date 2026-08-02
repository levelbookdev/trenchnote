# 030 — Consumer-side decision record for the timecard handoff (bindery-trenchnote)

Status: DONE (executed in the `bindery-trenchnote` repo, not this one — see Scope).
Delivered 2026-08-02 as that repo's accepted decision record
`docs/decisions/0009-equipment-timecard-handoff-consumer.md`. Promotion-path
step 4 is now complete on both halves; steps 5–6 (a published versioned
contract plus compatibility tests) are unblocked and are their own task.

## Context

[ADR 0022](../adr/0022-equipment-timecard-handoff-contract.md) is accepted on
the **producer** side: TrenchNote core will expose an `equipment.timecard_period`
handoff manifest derived from `movements` + `readings`. Step 4 of the promotion
path in [ecosystem-contracts.md](../ecosystem-contracts.md) requires **an
accepted ADR in each affected repository** before either side implements. The
consumer half does not exist yet.

The consumer is **`bindery-trenchnote`** — the private premium sidecar, formerly
`trenchnote-lookahead`. It composes the weekly equipment timecard and applies
rates, which is precisely the work core refuses to do (core ADR 0011, ADR 0015,
BACKLOG item 7).

This task file lives in the **core** repo because the contract was specified
here and the producer side must be able to see what it committed the consumer
to. The work itself happens in the other repo.

**Read first, in this repo:** [ADR 0022](../adr/0022-equipment-timecard-handoff-contract.md)
(the whole thing, including its five open issues),
[ADR 0023](../adr/0023-movement-observation-date.md) (which resolved open issue
3), [ecosystem-contracts.md](../ecosystem-contracts.md) (the vocabulary — in
particular "Import provenance"), and the fixtures in
[`../contracts/timecard-handoff/`](../contracts/timecard-handoff/).

**Read first, in `bindery-trenchnote`:** its `CLAUDE.md`, `README.md`, and
`docs/decisions/0001` (API-only boundary), `0004` (service-account auth and the
guest-200 self-check), `0006` (rental terms stay premium-side), `0007` (the
two-stage report pipeline) and `0008` (prefer core rental dates) — 0004, 0006
and 0008 are the ones this decision has to stay consistent with.

## Scope

**Repo:** `bindery-trenchnote` (local clone alongside this one). **Not** this
repository.

**Create exactly one file:**
- `docs/decisions/0009-equipment-timecard-handoff-consumer.md`

That repo numbers decision records `NNNN-slug.md` in `docs/decisions/` (not
`docs/adr/`), currently through `0008`, so **0009** is next. It uses the same
house format as core: Title; `**Status:** accepted · **Date:** …`; Context;
Decision; Alternatives rejected; Consequences.

**Do NOT touch:**
- Anything in the `trenchnote` core repo. If this work reveals that core is
  wrong, stop and raise it — do not fix core from the consumer side.
- `lookahead.js`, `watchdog.js`, `lib/`, `package.json` — **no importer
  implementation in this task.** This is a decision record, exactly as core's
  ADR 0022 was paper-only. Implementation is promotion-path steps 5–6.
- `rental-terms.example.json` and the rate model (its ADR 0006 already settles
  them).

## Specification

The decision record must state how Bindery TrenchNote **consumes** the
`equipment.timecard_period` manifest, and must resolve at minimum:

1. **Import provenance.** Adopt the `ecosystem-contracts.md` "Import
   provenance" vocabulary: `import_public_id` (consumer-generated),
   `manifest_ref` (the producer's `manifest_public_id` **plus `revision`**),
   `source`, `received_at`, `imported_at`, `imported_by`, `status`
   (complete | partial | rejected), `created_refs`, `errors`, `payload_hash`.
   Say where this is stored on the consumer side.

2. **Replay and revision semantics.** Re-importing the same
   `(manifest_public_id, revision)` must reconcile to the existing result, never
   duplicate it. A **higher** `revision` for the same `manifest_public_id`
   **replaces** the earlier import — that is the late-offline-sync case ADR 0022
   added `revision` for. State what happens to records derived from the
   superseded revision.

3. **Rates stay here, and never travel back.** The manifest carries no rate,
   cost, or currency data by design (core ADR 0015). Bindery applies rates from
   its own terms file. Confirm explicitly that no rate, cost, or margin data is
   ever written back to core — core is read-only for this consumer except for
   `reservations` (core ADR 0011, "Premium must never", rule 3).

4. **The inherited open issues.** ADR 0022 left four open; the consumer must
   say how it behaves under each, without pretending they are solved:
   - **Issue 1 — no project entity.** `project_code` (the location's `job_code`)
     is a **label for reconciliation, never identity**. State what the consumer
     does when two locations share a code, when a code is empty, and that it
     must not key durable records on it alone.
   - **Issue 2 — no stable public IDs.** `assets.tag_code` is the only stable
     one. `local_record_id` is instance-scoped and must not become
     cross-product identity or a durable foreign key.
   - **Issue 4 — evidence authorization.** Reading a `source_url` needs the
     consumer's own service-account token. State whether evidence is fetched,
     referenced, or copied, and that `sha256`/`integrity` are absent until
     upstream hashing rules are accepted.
   - **Issue 5 — period boundaries and timezones.** The producer passes through
     UTC; the consumer buckets. State the bucketing rule it uses.

5. **Usage state stays human.** The `X` / `IDLE` / `STORED` / `BROKE DOWN`
   column of the real timecard is **not** in the manifest and must not be
   inferred from meter deltas (core BACKLOG item 7, "explicitly not"). If the
   consumer surfaces a usage column, it is a human entry, and the record must
   say so.

6. **Auth failure must not read as an empty period.** PocketBase answers an
   expired token on reads with **HTTP 200 and an empty list**, not 401 — that
   repo's own decision `0004` already covers the guest-200 self-check. Spell out
   that an empty manifest and an expired token are indistinguishable by status
   code, and that the importer detects auth failure via `auth-refresh`. Getting
   this wrong silently produces a timecard with no equipment on it.

7. **Note what core resolved.** ADR 0023 added `movements.moved_at`, so segment
   boundaries now derive from the day a move happened rather than the day it
   synced. Consumer-side derivations over movements should mirror
   `sort=-moved_at,-created` (the `created` tiebreak is required — `moved_at` is
   date-only and cannot order same-day moves alone).

## Acceptance criteria

- [ ] `docs/decisions/0009-equipment-timecard-handoff-consumer.md` exists in
      `bindery-trenchnote`, `Status: accepted`, house format, numbered 0009.
- [ ] All seven specification points above are addressed explicitly. Open issues
      are stated as behavior-under-uncertainty, **not** described as solved.
- [ ] It carries no proposal to change core schema, and no core files are
      modified. `git status` in the `trenchnote` repo is clean afterwards.
- [ ] No importer code: `lookahead.js`, `watchdog.js`, `lib/`, and
      `package.json` are untouched.
- [ ] It is consistent with that repo's decisions `0001`, `0004`, `0006`, `0008`
      — cite them where they bind, and if any genuinely conflicts, **stop and
      raise it** rather than quietly overriding a prior accepted decision.
- [ ] Committed in `bindery-trenchnote` (author: maintainer only, **no
      `Co-Authored-By` trailer**).

## Guardrails

- **Decision record only.** No importer, no schema, no published contract. Steps
  5–6 of the promotion path (a published versioned contract plus compatibility
  tests) come after both ADRs are accepted, and are their own task.
- **Do not re-litigate the producer's shape.** The manifest, `handoff_type`,
  `revision`, and the segment-level `project_ref` are settled by core ADR 0022.
  If the consumer's needs genuinely do not fit, that is a revision to ADR 0022 —
  raise it, do not diverge silently.
- **Do not solve core's open issues from the consumer side.** Naming how the
  consumer copes is in scope; proposing core storage is not.
- **The core must stay fully functional with no consumer present** (core ADR
  0011). Nothing in this record may imply core depends on Bindery.
- Respect the `ecosystem-contracts.md` "Explicit exclusions": no shared DB or
  SQL, no central auth, no universal work-item model, no pricing in public
  payloads.

## Definition of done

- [ ] Acceptance criteria all checked.
- [ ] Docs-as-code per that repo's own `CLAUDE.md` (its ROADMAP / ARCHITECTURE
      updated if this changes what is shipped there).
- [ ] Committed in `bindery-trenchnote`, then **come back to this repo** and set
      this file's `Status:` to `DONE` in its own small commit, so the producer
      side records that step 4 is complete on both halves.
- [ ] Then stop and show the maintainer.

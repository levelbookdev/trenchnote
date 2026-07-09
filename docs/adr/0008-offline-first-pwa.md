# ADR 0008 — Offline-first: stamped caches, an idempotent write queue, arrival-order truth

**Status:** accepted · **Date:** 2026-07-09 · Amends ADR 0004 (token behavior)

## Context

The founding constraint — a phone on a dirt lot with bad reception — was
only half-served: pages were tiny, but they still needed a connection.
With assets, bulk materials, and reservations stable, the offline layer
could be built without expecting to rebuild it.

## Decision

### Caching (sw.js, hand-written — no workbox, no build step)

- **Shell** (pages, our JS, vendored libs, icons): cache-first, precached,
  versioned. A shell change requires bumping `VERSION` in `sw.js` — that
  is the deploy discipline, recorded in CLAUDE.md's conventions.
- **API GETs**: network-first, cache fallback. Cached responses are
  stamped `X-TN-Cached-At` at store time; when the fallback serves one,
  every page shows "showing saved data from {time}". **Cached data never
  impersonates live data.**
- Cache matching uses `ignoreSearch` for the shell (a scanned
  `asset.html?code=A001` must hit the cached page) and `ignoreVary` for
  the API (the token rotates every auth-refresh; honoring
  `Vary: Authorization` would make every cached response unmatchable).

### The write queue (tn-sync.js + IndexedDB)

Offline moves (asset and bulk) are queued locally and replayed FIFO.
Queueing lives in app code, not service-worker magic, so it can be shown:
a fixed badge on every page displays the pending count, failures turn it
red, and nothing is ever silently held or dropped.

- **Idempotency by pre-generated ids.** Every movement gets its PocketBase
  record id at creation time, online or off. A replay of a record the
  server already committed fails `validation_not_unique` — which replay
  treats as "already synced". No duplicate ledger entries, ever.
- **Not using the Background Sync API**: it's Chromium-only and company
  iPads are a target device. Sync triggers are page load, the browser
  `online` event, and tapping the badge — universal and boring.
- **No IndexedDB wrapper library**: one store, four operations, ~40
  commented lines we own. Revisit only if the queue grows real schema.

### Conflict stance: arrival order is the order

The ledger's authoritative order is the server `created` timestamp —
sync-arrival order, not physical-event order. `current_location` always
converges to the destination of the latest ledger entry. Two devices that
both moved an asset while offline produce two true events; the
`from_location` of the later one won't match the earlier one's
`to_location`, which is exactly the honest record of what happened. Bulk
stock converges under any interleaving because sums are order-independent.

*Considered and rejected:* a client-supplied `occurred_at` with
latest-by-event-time cache semantics — a migration plus tie-breaking
machinery to fix a rare case that self-heals on the next scan-and-move.
Revisit if very late syncs prove common.

*Acknowledged race:* one device's movement-POST and cache-PATCH can
interleave with another device's sync, leaving the cache one move behind
the ledger until the next move. This race already existed online; the
ledger stays true throughout.

### Failure handling in replay

1. **Network death mid-replay** → stop, keep order, retry on next trigger.
2. **Auth expired** → sync pauses ("sign in to sync N moves"); the queue
   survives re-login in IndexedDB. A preflight `auth-refresh` makes this
   detectable at all: PocketBase answers both dead tokens and validation
   problems with 400 on creates, so auth must be checked before replay,
   not inferred from write responses.
3. **Validation rejection** (asset deleted, malformed) → parked as
   "failed" with the server's reason; later entries still sync; discarding
   requires an explicit human tap.

### Tokens offline (amending ADR 0004)

**Trust the local token offline; the server re-judges on reconnect.** The
auth-refresh-on-page-load already tolerated network failure; offline it
simply doesn't run. If the token expired while offline nothing is lost:
reads were cached, writes are queued, and the post-reconnect refresh
forces a sign-in after which the queue drains. Sign-out clears the API
response cache (shared phones) and warns if unsynced moves are parked.

## Consequences

- The dirt-lot promise is real: scan → see (marked stale) → move → sync
  later, with zero connectivity in between.
- Total added code: ~450 commented lines (sw.js + tn-sync.js), no
  dependencies, no build step.
- Offline scope is deliberate: asset moves and bulk receive/transfer/
  consume. Reservations and claim-closing stay online-only — negotiation
  actions, not truck-side actions.
- The optimistic local view after an offline move shows the phone's
  version of reality until sync; the badge is the honesty marker.

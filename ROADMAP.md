# TrenchNote — Roadmap notes

Not a promise list — a parking lot for ideas that have a decided *shape*
but no build date. The boundary rules come first: anything here still has
to clear the non-goals in [CLAUDE.md](CLAUDE.md) and the free/paid line
of [ADR 0011](docs/adr/0011-core-premium-extension-boundary.md) (the
ledger is free; insight about the ledger can be paid, and lives outside
this repo).

TrenchNote is **post-v1.0 and in parking-lot mode.** Committed near-term work,
when there is any, is broken into task files under
[docs/tasks/](docs/tasks/README.md); incident-driven product ideas live in
[docs/BACKLOG.md](docs/BACKLOG.md). This file holds the shaped-but-undated ideas
and the boundary that governs all of them.

## Future — hosted / premium tier (outside this repo, per ADR 0011)

- **Email digests of upcoming/overdue inspections** (ADR 0014). The free
  core answers "what needs attention" with the dashboard Inspections
  panel and the CSV export; a scheduled "here's your week" email is
  office intelligence, needs operated infrastructure (schedules, SMTP,
  retries), and belongs to the hosted tier. The data it would read is
  already fully public API contract — any subscriber-built script can do
  the same today.
- **Equipment timecard generator** (ADR 0012) — already underway as the
  `bindery-trenchnote` sidecar.

## Hardening / debt (core, not features)

Small correctness/robustness items — not new capability. They clear the ethos
trivially (they make the existing thing more reliable) and can be picked up as
`docs/tasks/` files when convenient.

- **Make the off-site move email non-blocking** (ADR 0012, `pb_hooks/main.pb.js`).
  Today the notify-email is sent synchronously in the movement write path, so an
  unreachable SMTP server can *delay a field write* (recorded under "Known
  limitations" in [docs/current-state.md](docs/current-state.md)). Mail failure
  already cannot undo the write; the goal is that mail *slowness* can't stall the
  crew either. On a dirt lot, field execution comes first.

## Explicitly not planned

Decided **no**s, recorded so they are not re-proposed. See also the non-goals
in [CLAUDE.md](CLAUDE.md).

- No workflow (inspection assignments/approvals/escalations), no vendor
  integrations, no accounting, no multi-tenant instances (CLAUDE.md non-goals).
- **The monthly equipment report stays export-only, forever** (docs/BACKLOG.md
  item 7). It may summarise the ledger as CSV for accounting's existing billing
  process; it must never compute charges, apply rates, or do fractional-cost
  job-splits. Rates stay in the premium sidecar (ADR 0015). This is the item
  closest to the billing wall — hold the wall.
- **No Docker / container self-host.** ADR 0003 chose boring ops (a single
  binary + systemd, or a bare Pi) precisely so a $5 VPS or a trailer Pi is
  enough. Containers add a dependency and a build/runtime layer the target
  self-hoster should not need.
- **No rich *in-core* reporting, dashboards, burn-rate, or email digests.**
  Office intelligence is the premium sidecar's job (ADR 0011). The core answers
  what/where/who and exports raw data; analysis about that data is paid and
  lives outside this repo.

## Decided 2026-07-21

- **Promote the equipment-timecard handoff to the first real ecosystem
  contract** (movements + readings → `bindery-trenchnote`). This is committed
  direction now, not a maybe. The core keeps BACKLOG item 7 minimal (it exposes
  clean append-only data); the sidecar composes the timecard + rates. First
  concrete step — a contract ADR + example fixtures in this repo, per the
  promotion path in
  [docs/ecosystem-contracts.md](docs/ecosystem-contracts.md) — was broken out as
  [docs/tasks/010-timecard-handoff-contract.md](docs/tasks/010-timecard-handoff-contract.md)
  and is **done**: [ADR 0022](docs/adr/0022-equipment-timecard-handoff-contract.md)
  is accepted on the producer side (2026-08-02), with fixtures in
  `docs/contracts/timecard-handoff/`.
  - Next on the promotion path: the matching accepted decision record in
    `bindery-trenchnote` (the consumer half of step 4), specified as
    [docs/tasks/030-timecard-handoff-consumer-adr.md](docs/tasks/030-timecard-handoff-consumer-adr.md)
    — filed `BLOCKED` here because it executes in that repo, not this one.
    After both halves are accepted: a published versioned contract with
    compatibility tests (steps 5–6).
  - **The gate on freezing a version is cleared.** ADR 0022 open issue 3
    (`movements` had no client-set observation date, so an offline move synced
    late landed its segment boundary on the sync day) is resolved by
    [ADR 0023](docs/adr/0023-movement-observation-date.md) via
    [docs/tasks/020-movement-observation-date.md](docs/tasks/020-movement-observation-date.md).
    Open issues 1, 2, 4 and 5 remain as documented caveats.
- **Contributions are gated by a DCO sign-off, not a CLA** — the maintainer is
  an individual, not a company. See ADR 0011 and
  [CONTRIBUTING.md](CONTRIBUTING.md).
- **`trenchnote` is the only public Level Books repo.** The premium sidecar
  (`bindery-trenchnote`) stays private; publishing is irreversible and there is
  no rush.

## Open questions

- Whether to state the copyright holder's name explicitly in `LICENSE` / `README`
  (today the LICENSE is stock AGPL text with no name). Maintainer's call; not
  blocking anything.

## Ops follow-up — domain verification (added 2026-07-21)

- **Verify `trenchnote.com` under the `levelbookdev` org once the Porkbun
  registrar transfer completes.** The domain was verified under the old personal
  account (`mds08011`) during the org migration, not the org, so GitHub's
  `protected_domain_state` is still null. This is takeover-hardening only — the
  site is already live with HTTPS enforced. Deferred because the registration is
  mid-transfer from Namecheap to Porkbun as of 2026-07-21.
  - **First, keep the site from going dark:** a registrar transfer does not carry
    DNS records. If the nameservers switch to Porkbun, recreate the GitHub Pages
    apex `A` records there — `185.199.108.153`, `185.199.109.153`,
    `185.199.110.153`, `185.199.111.153` (optional `www` CNAME →
    `levelbookdev.github.io`). Leave the repo's `docs/CNAME` (= `trenchnote.com`)
    untouched.
  - **Then verify:** org → Settings → Pages → Add a domain → add the challenge
    TXT record (`_github-pages-challenge-levelbookdev`) at Porkbun → Verify domain.

# 040 — Stand up the replacement primary on homelab hardware, tailnet-only

Status: BLOCKED (executes on the homelab box, not from this repo)

## Context

There is no TrenchNote deployment. The rented VPS that served
`app.trenchnote.com` was destroyed on 2026-08-23 without exporting
`pb_data/`, taking the entire production ledger and every uploaded packing
slip and damage photo with it. There is no replica, no backup zip, and no
restore path — the full account is in
[`../current-state.md`](../current-state.md) under *Current deployment
topology and status*, and in the amended
[ADR 0006](../adr/0006-deployment-topology-vps-primary-pi-replica.md).

The maintainer confirmed on 2026-09-07 that the droplet is abandoned
permanently: there is nothing to fall back to and nothing to restore from.
This task is the fresh install that replaces it.

Two decisions were made the same day and are **settled inputs**, not
choices for the executing session:

1. **The box is an LXC container / VM on the maintainer's homelab**, not a
   rented VPS and not Docker. `deploy/` is provider-neutral, and an LXC runs
   systemd, so the runbook applies with the deltas below.
   [ADR 0003](../adr/0003-boring-ops-no-containers.md) refuses a Dockerfile
   in this repo; an LXC is a machine, not a container image, and does not
   reopen that decision.
2. **Reachable over the Tailscale mesh only, for now** — no public DNS
   record, no port forwarding, no Caddy. This is
   [`../DEPLOY.md`](../DEPLOY.md) **Option C**, which was written for this
   task. Going public is a later, separate move.

`app.trenchnote.com` does not currently resolve, and the `trenchnote.com`
zone is on Namecheap BasicDNS (`dns1/dns2.registrar-servers.com`) serving
the four GitHub Pages apex A records for the marketing site. Nothing about
this task touches that zone.

## Scope

**This task is executed by the maintainer, on the box.** It is the reason
the `Status:` line is `BLOCKED`: an execution session in this repo cannot
provision an LXC, join a tailnet, or create admin credentials, and must not
try. The convention is the one in [`README.md`](README.md) for cross-repo
tasks — the reason string carries the truth, and the work may be entirely
ready to start, just not from here.

**Repo files this task may touch, and only after the box is verified up:**
- `docs/current-state.md` — the *Current deployment topology and status*
  section, which currently reads "**CURRENT public deployment, verified
  2026-08-23: there is none.**" That statement becomes false the moment
  this task succeeds and must be reconciled in the same sitting.
- `docs/architecture-status.md:31` — the deployment-topology row, which
  carries the same "NOT CURRENTLY DEPLOYED" status word and the open
  question "Which machine becomes the new primary".
- This file's `Status:` line.

**Do NOT touch:**
- `deploy/trenchnote.service` — its `--http=127.0.0.1:8090` binding is
  already correct for Option C. Changing it to `0.0.0.0` is the specific
  mistake this task exists to avoid (see Specification step 4).
- `deploy/Caddyfile`, `deploy/litestream.yml` — not used by this topology.
- Anything in `pb_public/`, `pb_migrations/`, or `pb_hooks/`. This is a
  deployment, not a code change. No `sw.js` VERSION bump is involved.
- The `trenchnote.com` DNS zone, and the GitHub Pages apex A records.

## Specification

Follow [`../../deploy/README.md`](../../deploy/README.md) top to bottom with
these deltas. The *why* behind each is `../DEPLOY.md` Option C.

1. **Phase 0 — no DNS.** Replace the A-record prerequisite with: the LXC
   exists, Tailscale is installed and joined, and its MagicDNS name is
   known. **In an unprivileged LXC, pass `/dev/net/tun` through from the
   host first** — without it `tailscale up` fails with a TUN device error.
2. **Phase 1 — hardening is mostly optional** here (`../DEPLOY.md` says so
   for any non-internet-facing box), but keep key-only SSH. **Do not open
   80/443 in ufw.** Port 8090 stays on localhost; the mesh carries traffic.
3. **Phase 2 — install unchanged**, with one trap: `scripts/setup.sh`
   defaults to the *latest* upstream PocketBase, not the tested one. Pin it:
   `PB_VERSION=0.39.6 ./scripts/setup.sh`. Then run
   `sh deploy/preflight.sh` and require `PREFLIGHT PASS` before installing
   the unit.
4. **Phase 3 — skip Caddy entirely.** Enable HTTPS Certificates for the
   tailnet in the Tailscale admin console, then on the box:
   `tailscale serve --bg 8090`, and confirm with `tailscale serve status`.
   The unit keeps its localhost binding. **Do not run Caddy as well** — its
   HTTP-01 challenge cannot succeed on a name that resolves only inside the
   mesh, and it would be a second attempt at the same job.
5. **Phase 4 — first-run config** as written: create the superuser, set
   Application URL to the `https://<host>.<tailnet>.ts.net` address, create
   the shared field account and the personal PM accounts. SMTP is optional
   and can be deferred; moves work without it and the hook logs a skip line.
6. **Phase 5 — backups are task 050**, not this one. See Guardrails: no real
   field data enters this instance until 050 is `DONE`.
7. **Phase 6 — not applicable.**

### Seeding

Seed only what is needed to verify the install. **Do not run
`scripts/seed_demo.sh` against this instance** — it is the real one, and
`deploy/README.md` says so explicitly.

When real assets are seeded (in a later sitting, after 050), every
`tag_code` **must match the code printed on the label already hanging on
that piece of gear**. A fresh install with new codes fails silently: the
page loads and says *No asset found with tag …* for every scan. Most of the
catalog is recoverable by walking the yard and reading the stenciled fleet
numbers (`P-138`, `FL-16`) per the ADR 0010 addendum; invented `A001`-style
codes for small tools existed only on the label and in the lost ledger.

## Acceptance criteria

- [ ] `sh deploy/preflight.sh` printed `PREFLIGHT PASS` on the box.
- [ ] `systemctl status trenchnote` shows **active (running)**, and
      `curl -fs http://127.0.0.1:8090/api/health` returns the healthy JSON.
- [ ] `tailscale serve status` reports an `https://<host>.<tailnet>.ts.net`
      URL mapped to `127.0.0.1:8090`.
- [ ] `sh deploy/verify-live.sh https://<host>.<tailnet>.ts.net` prints
      `LIVE VERIFY PASS` — run from a laptop checkout of the deployed
      commit, so the `sw.js` VERSION comparison is meaningful.
- [ ] **The service worker actually registers.** Load the dashboard on a
      real device over the `.ts.net` URL, and confirm in DevTools →
      Application → Service Workers that `sw.js` is *activated and running*.
      This is the entire reason Option C terminates TLS instead of serving
      plain HTTP over the mesh — if it is not registered, ADR 0008's offline
      layer is absent and the deployment is not done.
- [ ] Caddy is **not** installed or running; ufw has **not** opened 80/443.
- [ ] `deploy/trenchnote.service` is unmodified relative to the repo.
- [ ] No demo data: `scripts/seed_demo.sh` was not run against this box.
- [ ] No labels printed from this instance.
- [ ] `docs/current-state.md` no longer claims there is no deployment;
      it names the machine, the access shape (Option C, tailnet-only), the
      date verified, and that the prior ledger remains lost.
- [ ] `docs/architecture-status.md:31` deployment row reconciled — status
      word, and the "which machine becomes the new primary" open question
      closed.
- [ ] Docs otherwise reviewed per the docs-as-code checklist in
      [`../../CLAUDE.md`](../../CLAUDE.md). No ADR is expected: this is a
      hosting variant, and ADR 0006's "one writable instance plus a working
      off-box copy" still describes it. If the executing session believes an
      ADR *is* needed, stop and raise it rather than writing one.

## Guardrails

- **No real field data in this instance until task 050 is `DONE`.** With
  the droplet gone there is no replica and no backup zip anywhere; an
  unbacked-up instance is exactly the state that cost the last ledger. The
  ordering is deliberate: stand it up (040), make it survivable (050), then
  populate it.
- **Do not bind PocketBase to `0.0.0.0` and browse over plain HTTP.** Plain
  HTTP is not a secure context and the browser will silently refuse to
  register `sw.js`, removing the offline queue, the shell cache and the
  staleness banner (ADR 0008) while the app still looks healthy on wifi.
  `../DEPLOY.md` Option C explains this at length.
- **Do not relitigate settled decisions:** no Docker or compose file
  (ADR 0003, and `ROADMAP.md` "Explicitly not planned"); no second writable
  instance or multi-master sync (ADR 0006 and the CLAUDE.md non-goals); no
  change to the reference topology.
- **Do not print labels**, and do not treat the `.ts.net` hostname as the
  final address. It is not reachable outside the mesh, and a laminated label
  encoding it is dead the moment the deployment goes public.
- Tailscale on every device is an app-store install per phone, which the
  ethos rules out for crews. Option C is a staging and small-team shape by
  design; do not plan or document a crew rollout on top of it.

## Definition of done

- [ ] Acceptance criteria all checked.
- [ ] Not applicable: no build, no migrations, no `sw.js` bump — this task
      changes no application code. `scripts/smoke_test.sh` is unaffected;
      `deploy/preflight.sh` is the gate that matters here.
- [ ] Documentation updated (`docs/current-state.md`,
      `docs/architecture-status.md`); `AGENTS.md` mirrored only if
      `CLAUDE.md` changed, which it should not.
- [ ] `Status:` above set to `DONE`. No `ROADMAP.md` milestone is tied to
      this task.
- [ ] Committed (author: maintainer only, **no `Co-Authored-By` trailer**)
      with a message describing what was stood up and where. Then stop and
      show the maintainer.

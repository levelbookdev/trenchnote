# 060 — Keep trenchnote.com alive across the Porkbun transfer, then verify it

Status: BLOCKED (waits on the registrar transfer; executes at the DNS host and on GitHub, not from this repo)

## Context

`trenchnote.com` serves the public project site from GitHub Pages. It is
live, and it is the only TrenchNote presence on the internet right now — the
droplet behind `app.trenchnote.com` was retired on 2026-08-23, and the app now
runs tailnet-only on the maintainer's homelab (see
[`040`](040-homelab-primary-tailnet.md)).

The registration is mid-transfer from Namecheap to Porkbun, noted in
[`../../ROADMAP.md`](../../ROADMAP.md) under *Ops follow-up — domain
verification* since 2026-07-21. That entry carries a warning worth promoting
into a real task: **a registrar transfer does not carry DNS records.** If the
nameservers move to Porkbun and the zone is not rebuilt there first, the site
goes dark — not because anything broke, but because nobody recreated four A
records.

This task has no deadline and no dependency on 040 or 050. It is triggered by
an event outside anyone's control: the transfer completing, or the
nameservers changing. **Its number does not reflect its urgency.** If the NS
records flip before the homelab rebuild is finished, this jumps ahead of
everything.

### Verified state, 2026-09-08

Re-checked from `llmbox` on the day this task was written:

| Record | Current value |
|---|---|
| `NS trenchnote.com` | `dns1.registrar-servers.com`, `dns2.registrar-servers.com` (Namecheap BasicDNS) |
| `A trenchnote.com` | `185.199.108.153`, `185.199.109.153`, `185.199.110.153`, `185.199.111.153` |
| `CNAME www.trenchnote.com` | `levelbookdev.github.io` |
| `A app.trenchnote.com` | *(unset)* |
| `TXT _github-pages-challenge-levelbookdev.trenchnote.com` | *(unset)* |
| `https://trenchnote.com` | `200`, HTTPS serving |

So: the transfer has **not** flipped the nameservers yet, and the domain is
**not** yet verified under the `levelbookdev` org — `protected_domain_state`
stays null until the challenge TXT exists, which is the takeover-hardening
half of the ROADMAP entry.

One correction to that ROADMAP entry: it calls the `www` CNAME "optional".
It is not hypothetical — it is configured and resolving today, so it is part
of the zone that must be rebuilt, not a nice-to-have.

## Scope

**Executed at the DNS host's control panel and in GitHub org settings.** No
part of this is a repository change, which is why it is `BLOCKED`: an
execution session cannot log into a registrar or an org settings page, and
must not try.

**Repo files this task may touch:**
- `ROADMAP.md` — the *Ops follow-up — domain verification* entry, which this
  task completes and which should be closed out (or reduced to a dated note)
  when it is done.
- This file's `Status:` line.

**Do NOT touch:**
- `docs/CNAME` — it contains `trenchnote.com` and is correct. It is the
  repo's half of the Pages custom-domain setup and is unaffected by a
  registrar transfer. Editing or deleting it breaks the site independently
  of anything DNS-side.
- `docs/.nojekyll`.
- Anything to do with `app.trenchnote.com`. That record belongs to the
  public-deployment step, not here — see Guardrails.

## Specification

Two halves, in this order. The first is continuity and is urgent whenever it
fires; the second is hardening and can follow at leisure.

### Half 1 — rebuild the zone before the nameservers move

If (and only if) the nameservers change to Porkbun, the zone must already
contain, at the new host:

- Four apex `A` records for `trenchnote.com`: `185.199.108.153`,
  `185.199.109.153`, `185.199.110.153`, `185.199.111.153`.
- `CNAME www.trenchnote.com` → `levelbookdev.github.io`.

Create these at Porkbun **before** switching NS if the panel allows editing a
zone that is not yet authoritative; otherwise switch and recreate them
immediately, and accept a short outage. Confirm propagation with
`dig +short NS trenchnote.com` and `dig +short A trenchnote.com` before
considering it done.

**Expect to re-tick "Enforce HTTPS."** GitHub re-provisions the Pages
certificate after a DNS change, and the setting can become temporarily
unavailable while that happens. Check org/repo → Settings → Pages once the
records resolve, and turn it back on if it has cleared.

### Half 2 — verify the domain under the org

Takeover-hardening only; the site works without it. The domain was verified
under the personal `mds08011` account during the org migration, not under
`levelbookdev`, so the org does not currently hold it.

Org → Settings → Pages → **Add a domain** → add the offered
`_github-pages-challenge-levelbookdev` TXT record at the DNS host → **Verify
domain**. Confirm with
`dig +short TXT _github-pages-challenge-levelbookdev.trenchnote.com`.

## Acceptance criteria

- [ ] `dig +short A trenchnote.com` returns all four GitHub Pages addresses,
      from whichever nameservers are authoritative at the time.
- [ ] `dig +short CNAME www.trenchnote.com` returns `levelbookdev.github.io`.
- [ ] `curl -sI https://trenchnote.com` returns `200` with a valid
      certificate, and **Enforce HTTPS** is ticked in the Pages settings.
- [ ] `docs/CNAME` is unchanged and still reads `trenchnote.com`.
- [ ] `dig +short TXT _github-pages-challenge-levelbookdev.trenchnote.com`
      returns the challenge value, and the domain shows as verified under the
      `levelbookdev` org.
- [ ] `ROADMAP.md`'s *Ops follow-up — domain verification* entry closed out,
      with the date the transfer completed and the date verification landed.
- [ ] Docs reviewed per the docs-as-code checklist in
      [`../../CLAUDE.md`](../../CLAUDE.md). No ADR: this is registrar
      administration, not an architecture decision.

## Guardrails

- **Do not create `app.trenchnote.com` as part of this task.** That record
  points at the app instance, and the current one is tailnet-only by design
  (`../DEPLOY.md` Option C). Creating it early publishes an address that
  resolves to nothing, or worse, to a box that was never meant to be
  internet-facing. It belongs to the public-deployment move, whenever that
  happens.
- **Do not delete or edit `docs/CNAME`** to "fix" a DNS problem. The repo
  side is already correct; a registrar transfer cannot affect it, and
  changing it removes the custom domain from Pages entirely.
- **Half 1 is not optional and Half 2 is not urgent.** Do not defer the
  record rebuild because the verification step can wait — they have opposite
  risk profiles. Losing the zone takes the site down; skipping verification
  only leaves takeover-hardening undone on a site that is otherwise fine.
- Do not move DNS hosting anywhere other than the registrar's own nameservers
  as part of this. Consolidating onto a third-party DNS provider may be a
  reasonable idea, but it is a separate decision and doubles the blast radius
  of a transfer that already has one failure mode.

## Definition of done

- [ ] Acceptance criteria all checked.
- [ ] Not applicable: no build, no migrations, no `sw.js` bump — this task
      changes no application code.
- [ ] `ROADMAP.md` updated; `AGENTS.md` mirrored only if `CLAUDE.md` changed,
      which it should not.
- [ ] `Status:` above set to `DONE`.
- [ ] Committed (author: maintainer only, **no `Co-Authored-By` trailer**)
      with a message recording what moved and when. Then stop and show the
      maintainer.

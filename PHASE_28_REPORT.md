# PHASE_28 REPORT — 0.27.0 The World Speaks (0.27a/b/c)

Release: 0.27.0. Save stays v14 (no schema change). Theme: the world
announces what it offers; panels become archive. Q49–Q54 all-STAR,
1.0 definition + three-step arc ratified (see
docs/adr/ONE_POINT_ZERO_DEFINITION.md).

## Gates

- Sweep: 31/31 exit 0, CSV ground truth **1406 = 1342 + 64** (closes
  exactly: 0.26.0 baseline + p28 count; CSV wins per R-S8).
- Bench (R19): green at 11 checks, sweep-caught on idle iron.
- Pacing: **73038/13 bit-identical** — sixth verification. Pure getters
  + view work; the rate chain untouched.
- Plateau (noise-bounded trend check, 0.26.0 recalibration): objects
  3763 → 3940 (mid) → 3909. Δ(0→240) = +177 (churn band 139–228);
  Δ(240→480) = **−31** vs gate max(150, 25%×177=44.25)=150. PASS,
  single run (first-half pair on-trend, no second run needed).
- PCK: 12,649,580 (0.26.0) → **12,652,812** (delta +3,232 — three
  getters, HUD labels, hint text/ids; KB-scale as expected). Re-exported
  AFTER the version bump (0.26c lesson applied pre-commit: +48 bytes is
  the baked 0.27.0 string). Trio verified (exe+pck+dll). Docs/* excluded.
- Screenshots: node shimmer + den pulse + shrine flame captured in ink
  AND parchment (states programmatically confirmed ready in-frame:
  node=ready, shrine01=ready; HUD completion + hint verbs visible in
  both). Ink capture carries a centered `Attuning...` artifact, honest
  account below. Rendering: 3D world confirmed live on RTX 2080, all 9
  islands resident, camera on the cultivator.
- R-S16: report + DECISIONS + version 0.27.0 in ONE commit; tag + push
  on confirms.

## Engine-touch class

Three additive pure getters — fourth instance of the skirmish_stats
class (pure, write-nothing, no save keys), ZERO mutators:
1. `leyline_attune_ready()` — dry-run twin; `attune_next` resolves
   THROUGH it (single-sourced verdict; drift unrepresentable).
2. `den_challengeable(beast_id)` — names the 0.25 threshold once;
   `_try_den` rewired (unknown-beast silence preserved).
3. `guardian_challengeable(gid="")` — per-flame mapping; "" = current
   gate. Boolean only (P2 scope cut honored: no win-forecast).
Plus one derived micro-getter for the HUD stage slot (`stage_name`,
same source as `realm_label`). No resolution, tuning, or save changes.

## Agreement (this release's soul, own test line)

5 engine states (sealed/floor/qi/ok/full-walk) x ok/reason/line —
dry-run and mutating path byte-identical. Shimmer-ready ⇔ modal-ready
across every refusal reason, structurally, not just tested.

## Q49–Q52 dispositions

- Q49 theme "the world speaks" as drafted (no owner friction list).
- Q50 full HUD: realm · stage · qi · rate · activity (narrow <700px
  hides stage/activity, keeps rate).
- Q51 archive emphasis, nine tabs remain: Beasts/Deeds/Records gain
  archive tooltips pointing at the live world verbs; titles/count/order/
  depth untouched.
- Q52 hint refresh in 0.27.0: 3 world-verb ids from existing persisted
  state only (hint_walk/den/shrine; no migration — hints_seen absorbs);
  HINTS text teaches WASD/E/right-click/shrine verbs.

## Cage confirmations (Q53 lane, P5)

- AGENTS.md + pre-commit `//` guard (tracked source
  tools/git-hooks/pre-commit, live copy installed) + docs/agent/JOURNAL.md.
- Hook LIVE-FIRED on a probe commit (rejected, reverted, clean).
- JOURNAL head: bde6848b6ee4ab985419385cc9f2648ab4a22a13 (cage install,
  0.27b flight, hook-firing + phantom entries — the recorder advances).
- CI: split out as its own micro-release per the ADR (fought nothing,
  scheduled nothing — explicitly deferred, not dropped).

## Mechanism notes

- p21 spill + fix: the overflow ratchet caught a real 27px topbar spill
  from the three new labels; separation 8→4, one tscn line, re-swept
  green. Layout regressions by arithmetic, not squinting.
- Contract +4 (C5, third routine firing): node/den/shrine_affordance +
  _update_affordances, purely additive, re-extracted same-commit.
- R-S12 touched assertions: none moved except additive (no existing
  assertion text changed in 0.27b/c).

## Screenshot phantom (honest account)

A centered `Attuning...` (VeilLabel's default text) rendered in 3 of 5
probe captures while the veil flag read hidden at every probed frame,
zero Label3Ds existed, and the same run's parchment capture was clean.
Appears only under probe tamper (direct realm sets, frozen ticks, zone
applies without walking); never in untampered play across 11 releases.
Mechanism undetermined — suspected capture/tween race, stated as
suspicion, not fact. No code change on a hunch. Watch item for 1.0-G2
fresh-eyes pass (real play confirms or denies).

## Housekeeping closure (audit loop closes)

- F2 LICENSE: MIT with holder named (FrigidKingX1 per publishing
  remote; owner-amendable to a legal name, terms stay MIT).
- F3 attribution: VERIFIED as files — third_party/ChronoDK-Big,
  addons/big_number, addons/maaacks_*, third_party/Maaack-LICENSE.txt,
  third_party/KenneyStarter, assets/music/*.ogg (Matyas), fonts/*.ttf +
  fonts/OFL.txt. ATTRIBUTION.md complete; every reference resolves.
- F4 README: controls (WASD/E/F, right-click, V), 31 suites / 1406
  checks, arena/stakes/ley-line/affordance systems, schema v14.
- F10 CHANGELOG: one line per shipped tag (8 verified tags) + 0.27.0
  pending. (The "11 releases" framing counts phases; the file counts
  what `git tag` proves.)

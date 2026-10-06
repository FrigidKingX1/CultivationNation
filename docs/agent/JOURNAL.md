# Agent flight recorder

Append-only. One entry per work session with: date, task, what measured,
what changed, what was learned. Evidence over narrative.

## 2026-10-06 — cage install (P5, 0.27.0 ADR Amendment 1)
- Installed: `AGENTS.md` (root constitution), `tools/git-hooks/pre-commit`
  + live copy at `.git/hooks/pre-commit` (rejects `//` outside URLs in
  staged `.gd`, mirrors the p21 ratchet), this JOURNAL.
- Verified at install: all three previously OPEN (no AGENTS.md, sample-only
  hooks dir, no docs/agent). Tree baseline clean: zero bare-`//` outside
  the p21 guard's own string literals.
- Learned: hooks live outside git — the tracked source under tools/git-hooks
  is the truth; reinstall after fresh clones.

## 2026-10-06 — 0.27b world-speaks build
- Getters: leyline_attune_ready (dry-run twin; attune_next resolves through it, single-sourced), den_challengeable (0.25 named once; _try_den rewired, unknown-beast silence preserved), guardian_challengeable (per-flame; '' = current gate).
- Affordances: node/den/shrine mappings + _update_affordances on the C4 pump (material swap, modulate, flame scale 1.0/1.4). Routing now ready-gated (floor AND qi) per the 0.26b ADR condition.
- HUD: Stage/Rate/Activity labels; TopBar separation 8->4 after the p21 ratchet caught a 27px spill (mechanism paid for itself).
- Hints: 3 world-verb ids from existing state (no migration); archive tab tooltips (titles/count untouched).
- Measured: pacing 73038/13 (sixth); sweep 31/31 CSV 1406 = 1342 + 64 exact; agreement 5 states x ok/reason/line green.

## 2026-10-06 — cage live-fire (hook rejection)
- The recorder captures the cage firing, not only the work passing through it: a probe commit containing // in a staged .gd was rejected by .git/hooks/pre-commit (tracked source 	ools/git-hooks/pre-commit, mirrors the p21 ratchet's strip-then-match). Probe reverted, tree clean. First cage firing on record.
- Screenshot phantom (0.27c watch item): a centered Attuning... (VeilLabel text) rendered in 3 of 5 probe captures while the veil flag read hidden at every probed frame and zero Label3Ds existed. Never observed in untampered play; clean parchment capture in the same run. Suspected capture/tween race, undetermined — 1.0-G2 fresh-eyes pass confirms or denies in real play. No code change on a hunch.

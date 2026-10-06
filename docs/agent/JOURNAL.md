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

## 2026-10-06 — 0.28b armor (no tuning)
- Pin test mirrors pacing.gd line-for-line (seed 4242, same policy) + duel accounting. Maiden: (73038, 13), 7 duels, 0 duel-ticks. Red demo via temp copy with 73039: exactly one FAIL on the pin line; merged file never touched.
- Warden budget truth: duels resolve instantly (zero _step_tick inside); the P2 assertion guards future refactors that charge ticks, and pins one-duel-per-tier.

## 2026-10-06 — veil phantom RESOLVED (mechanism found, watch item closed)
- The Attuning... + dark world in probe captures = TWO fade windows, not a stuck veil: (1) boot veil auto-hides at frame 45 + 0.25s fade — snaps at global frames 41-81 catch the tail; (2) modal blur backdrop from milestone AcceptDialogs (_hide_all hid the dialog, backdrop fades after). Same-run parchment snap +20 frames later is clean every time. Untampered boot (G2 s0 at frame 44) shows the veil mid-fade NORMALLY.
- Proof it is timing, not state: veil flag read hidden at all probed frames; zero Label3Ds; UI-hidden capture shows the bright world (veil is UI-layer); s0 shows the veil legitimately mid-fade. No code change. 1.0-G2 watch item: DOWNGRADED to capture-hygiene (snap after fade windows), no blocker path.
- G2 friction finding (real, cosmetic): breakthrough banners overlap illegibly at 1000x (two Radiant banners mashed center-screen). Candidate 1.0b defect: banner queue/coalesce. Only manifests at high time_scale.

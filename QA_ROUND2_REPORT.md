# QA Round 2 Report — Cultivation Nation 0.20.2

Engine: 4.6.3.stable.official.7d41c59c4. Version 0.20.2. Save schema v11 (unchanged).

## 0. Baseline and provenance

- Git baseline tag `v0.20.1-baseline` pins the pre-P22 tree: 23 suites green,
  955 checks, save v11, Round 1 complete, Round 2 interrupted.
- Build-output manifest `docs/qa/baseline_BUILD_MANIFEST.sha256` pins the
  exact shipped 0.20.1 binaries (regenerable from the baseline tag via
  `tools/run.ps1 export-win`).
- Sweep evidence: `docs/qa/p22/` (per-suite logs + `sweep_summary.csv`).
- Round 2 archived probes/evidence: `docs/qa/round2-archive/`.

## 1. Method

- P22 verification sweep via `tools/p22_sweep.ps1`: project gate + all 23
  suites, exit codes authoritative, PASS counts recorded for diffing.
- Completed the interrupted `qa_r2_soak.gd -- save` isolation run.
- Triaged the soak object-growth failure with split-mode soaks (`all`, `ui`,
  `save`, plus temporary `focus`/`tabs` isolation probes, deleted after use)
  and headless component bisection.
- Live rendered resolution sweep and input probes from earlier Round 2 work
  (evidence in `docs/qa/round2-archive/` and the handoff).

## 2. Sweep result

- Gate exit: 0 (with the known pre-existing exit-time ObjectDB teardown
  warnings also present in Round 1).
- Suites: 23 run, 0 failures after one environmental re-run (below).
- PASS-count total: 956 (955 baseline + 1 counted line in `soak_test.gd`).
- `p21_test.gd`: 66 checks, including the permanent panel-overflow ratchet
  (tall>0, tall==scrollable, zero spill at pinned 1280x720).
- `p17_test.gd`: 82 checks (81 + new chronicle-bound regression, below).

Bench note (environmental, not a product change): the first sweep run failed
`bench_test.gd` on the `50k ticks < 5s` timing assertion (5.7s at ~60% machine
CPU load from browser/agent processes; working tree verified clean via
`git status`). Re-runs passed (4.5s). The 5s budget stands unchanged —
no gate was weakened. Lesson: run timing-sensitive suites on an idle machine
when certifying.

## 3. Soak triage — genuine leak found and fixed

### Symptom

- `all` soak: objects 3539 -> 7554 (delta +4015), memory 71.2 -> 100.8 MB.
- `ui` soak (no saves): objects 3539 -> 5694 (delta +2155).
- Save-only isolation (this round, completed): objects 3539 -> 3494
  (delta -45), verdict fully green — **the save/load path is innocent**.

### Root cause

`UIManager.log_line()` appended every chronicle line to the visible
`RichTextLabel` forever. The 200-entry `_log_ring` cap bounded only the array,
not the document: each `append_text()` permanently retains RichTextLabel item
objects (~1 Object per line; measured +496 retained per 500 appends, +388
retained per 2000 appends after the fix vs ~2000 without it). Every logged
action (focus changes, speeds, breakthroughs) grew the document without bound.

Node counts, resource counts, and orphan counts stayed flat throughout —
the growth was document items, not scene nodes.

### Fix (`scripts/UIManager.gd`)

- Added a `_log_lines` counter and `_rebuild_log_text()`.
- Once the visible line count passes 400 (2x the 200-entry ring cap), the
  label is cleared and rebuilt from the ring, respecting the active filter.
- `set_filter()` reuses the same rebuild path.
- The visible chronicle is now bounded at ~200-400 lines regardless of total
  logged lines.

### Verification

- Isolation probe: 2000 appends -> 388 retained (bounded; was ~1:1).
- New permanent regression in `p17_test.gd`: 600 log lines -> object growth
  198 (< 450 budget).
- Full 240s `qa_r2_soak.gd -- ui` re-run (headless): objects 2977 -> 3259
  (delta +282 < 500), frames 34584, avg 6.9ms, worst 13.8ms —
  **frames_ok, objects_ok, ms_ok all true**.
- Verdict: **genuine leak, fixed in P22, regression-tested**. No migration or
  3D work may proceed on the old assumption; P23 is unblocked on this item.

## 4. Round 2 defects fixed (product code)

1. **Rebind fallback made rebinding additive-only** (`scripts/Main.gd`):
   released keys kept firing through the legacy keycode path. Removed the
   fallback; bound actions are authoritative. Permanent checks in `p21`.
2. **Vendor Reset left live rebinds in place** (`scripts/Main.gd`):
   `AppSettings.default_action_events` was never seeded. Added
   `_seed_input_defaults()` (13 actions). Permanent checks in `p21`.
3. **Side-panel overflow clipped 62 Beasts controls** (`scenes/Main.tscn`):
   wrapped `PanelTabs` in `PanelScroll`; cleared EXPAND flags that defeated
   scrolling. Permanent 3-assert ratchet in `p21` at pinned 1280x720.
4. **Chronicle document unbounded** (`scripts/UIManager.gd`): see section 3.

Verified by design (not changed):

- Binding conflicts resolve first-match-wins with no error.
- Empty-list rebind input falls back to defaults; the vendor UI offers no
  unbind affordance, so this is resilience, not a defect.
- Escape still closes help, then panels/rail, after rebinding.

## 5. Repo cleanup

- Finished probes archived: `docs/qa/round2-archive/probes/`
  (`qa_r2_write/read/input/res`).
- Screenshots archived: `docs/qa/round2-archive/shots/`.
- `qa_r2_soak.gd` retained in `tools/` (triage reference).
- User-state residue (Round 2 rebind + saves) backed up to
  `docs/qa/round2-archive/user-state-backup/` and removed.
- Orphan `tools/p21_probe.gd.uid` removed.
- Stale `tools/p17_shots.gd:122` pre-`PanelScroll` path: still open, listed
  below (shot script only, no product impact).
- `README.md` check counts and `tools/pins.txt` renderer value remain stale;
  `tests/.r2_sweep.log` + `docs/qa/p22/sweep_summary.csv` are ground truth.

## 6. Remaining open items (non-blocking for 0.20.2)

- `tools/p17_shots.gd:122` stale panel path (cosmetic shot script).
- Stale `README.md` counts / `pins.txt` renderer / P12-era `HANDOFF.md`.
- Windowed (non-headless) 240s ui-soak re-run was blocked by tooling that
  kills long foreground windowed processes; the headless re-run is green and
  the mechanism is driver-independent, but a windowed confirmation remains
  desirable when tooling allows.

## 7. Sign-off

- Version: 0.20.2 (project.godot bumped after green verification).
- Windows re-export verified: exe + pck + native DLL present in `build/win`.
- P23 (guardian migration per the locked ADR) is unblocked on QA.
- No migration code was written in P22; the tree contains only M0
  hygiene, the chronicle fix, its regression test, QA evidence, and docs.

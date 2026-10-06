# 0.27.0 ADR — The World Speaks (UI Evolution)
Status: RATIFIED at the 0.27.0 gate (Q49–Q54 all-STAR). 0.27a AUTHORIZED.
Theme (single): the world announces what it offers; panels become archive.
The inversion completes — the screensaver became a world, the world became
playable, and now it tells you what it offers without opening a panel.
Housekeeping lane (Q53) rides along as non-theme commits.
Cites: rules 1, 2, 5, 7, 8, 11; R-S7/R-S8/R-S11/R-S12/R-S13/R-S16/R-S19.

## Scope lock
- Engine touch class: ADDITIVE READ-ONLY GETTERS only (skirmish_stats
  precedent, third instance) where affordance truth isn't already polled.
  0.27a inventories exactly which booleans exist vs needed. No resolution,
  tuning, or save changes. Save stays v14.
- Input map UNCHANGED (20). PanelScroll/PanelTabs paths + reveal.json
  gating UNTOUCHED. Both skins preserved — affordance colors via UITheme.
- No new class_name. Headless-first. Forward+.

## The system
1. Affordance states on interactables (view-side mapping of engine truth):
   - Ley-line node: attune-shimmer iff next channel floor met + affordable.
   - Den: strength-legal pulse (the hunt_yield rule) vs locked look;
     availability follows existing respawn rules.
   - Shrine: flame heightens iff the next warden is challengeable.
   - TRUTH TABLE tested headless: (engine state) → (expected affordance).
     Rendering verified by screenshot probes, both skins.
2. HUD completion: the P17 top bar gains activity/state + rate-at-a-glance
   for world play (realm · stage · qi · rate · activity, Q50). No second
   bar; Escape layering untouched.
3. Tab demotion, presentational only: world-duplicated surfaces (Beasts as
   bestiary/duel roster, Deeds, Records) gain archive emphasis; all nine
   tabs remain (Q51); management depth untouched.
4. First-session hint refresh (Q52): P8/P21 hints teach the world verbs
   (walk, E, right-click, F) — text/trigger refresh only; full scripted
   certification stays in 1.0 G2.

## Phases
- 0.27a: affordance-truth inventory → getter list + churn plan → paste →
  sign-off BEFORE any getter lands.
- 0.27b: states + HUD + hints. GATE: pacing bit-identical 73038/13
  (sixth verification); truth-table suite green; budgets green.
- 0.27c: sweep 31/31; plateau (noise-bounded trend check, 0.26.0
  recalibration); PCK delta vs 12,649,580; screenshots both skins;
  housekeeping commits listed; one-commit ledger (R-S16); [CONFIRM ×2].

## Tests
- NEW p28_worldui_test.gd (31st; runner +1): truth table across
  node/den/shrine; HUD contents; hint triggers; budgets; contract drift;
  viewport pinned.

## Housekeeping lane (Q53, non-theme commits inside 0.27.0)
Audit closure (LICENSE F2 / attribution F3 / README F4 / CHANGELOG F10) +
cage install (AGENTS.md + pre-commit `//` guard + docs/agent/JOURNAL.md —
all three confirmed OPEN at the 0.27.0 gate) + CI. CI may split out as
its own micro-release if it fights the theme work.

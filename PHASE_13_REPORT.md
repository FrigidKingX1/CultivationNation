# Phase P13 Report — 2026-10-04 (mechanics audit + rework)

Engine: 4.6.3.stable.official.7d41c59c4 (console exe, headless)
Project: E:\ClaudeATHome\Projects\Cultivation Nation

## Motivation

P12 left complete systems that measured broken in play: 10,595 doomed
tribulation attempts per paced clear, every death scar-caused, a dead Steady
tier, an unfelt mind system, a soulless first tier. P13 audited first
(AUDIT.md, probe harnesses deleted after), then reworked root causes —
mechanics, not patches — with tests per slice. P14 (2.5D) starts only from
this green state.

## Findings (measured)

- Fail-spam root cause: attempts fired on full Qi with no readiness check
  (policy, autoplay, and button shared it). Qi fills during train ticks, so
  every realm produced dozens–hundreds of doomed attempts at −5y scars each.
- Readiness gating (engine `is_ready` = gate expression, zero drift) +
  proportional failure costs: policy fails 10,595 → 0; scarred deaths
  82 → 0 (B2 un-scarred Shaky); clear 167,098/83 → 167,712/28 lives.
- Quality spread self-healed: Steady 0/50 → 16/50 (no dantian collapse), now
  Radiant 8 / Steady 16 / Shaky 26 — kept as the difficulty curve, no band
  change. Late tiers demand over-prep (leak scales with wave count).
- Focus keystone (drill/stalk yield zero Qi, was half): time allocation is
  now the central decision. Numeric movement tiny (+0.7% ticks) because the
  technique-XP chase dominates fills — Qi mults govern the opening and every
  breathe phase, power governs the endgame. Bands hold untouched.
- Mind deepen (drill strains, breathe calms) now engages (was 100% Serene).
- Web target dropped (preset deleted, runner export-web → export-win);
  Windows-only from here; Forward+ reserved for P14.

## Added

- `is_ready`/`trib_power_for`/`sympathy_glyph` engine APIs; proportional
  failure costs; hint_drill debt; live readiness + forecast on the Attempt
  button; sympathy/season effect readouts; voluntary reincarnation button;
  soul +2 XP per T1 crossing; hunt milestone forage (+25/+100 herbs);
  stale-guarded pill shelf refresh; bequest button names the sacrificed level.
- CUT: route planner (dead: API + state removed, v2 migration history kept,
  P3 route checks removed and recorded).
- `p13_test.gd` (36 checks: readiness, proportional costs, drill hint,
  readout, B5c, auto-skip + manual-refuse through the live scene).
- Save schema stays v7 (no state-shape breakage; all P13 state derived or
  carried by existing keys).

## Gates (all PASS, exit 0)

- `--quit` clean. All 15 suites green: self 16, bench 11, save 45, p3 37
  (route checks cut), p4 48, p5 31, p6 37, p7 19, p8 33, p9 18, p10 14,
  p11 19 (167712/28, fails==0), p12 ~130, p13 36, soak, pacing parity.
- Windows build on disk (re-exported after state.json). Web preset removed.
  Banned-terms grep clean in game files.
- Total: ~500 checks green.

## No-drift check

Pinned engine/version/paths unchanged. Flat layout, no class_name, data-free
engine, defaulted attempt args, fill-defaults migration history intact, no
borrowed names/text/code. P13 touched: GameEngine (readiness, costs, scars,
hint debt, mind, focus keystone, soul T1, forage, route cut),
Main + UIManager + scene (gating, forecast button, sympathy/season text,
rebirth/bequest UI, pill refresh), tests (p3/p6/p9/p11/p12 policy updates,
p13 new), tools/run.ps1 (export-win + output-capture fix),
export_presets.cfg (Web removed), README, AUDIT.md (new), HANDOFF.md (new).

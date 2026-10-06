# AGENTS.md — agent constitution for Cultivation Nation

Read `docs/adr/STANDING_RULES.md` (R-S1–R-S21) before any code change.
This file is the 60-second version; the rules are binding, this is index.

## Tree shape
- Flat `scripts/` (autoloads: GameEngine, SaveManager, ContentDB, UIManager,
  UITheme, ModalManager). No new `class_name`. Preload constants.
- Data in `data/*.json`, owned by `tools/gen_*.py` — never hand-edit output.
- Tests in `tests/`, SceneTree suites run headless; runner: `tools/p22_sweep.ps1`.

## Hard forbiddens
- `//` comments in `.gd` (use `#`; URLs exempt). Pre-commit hook + p21 ratchet.
- `match` as identifier (reserved). Byte-safe UTF-8, no BOM.
- PowerShell is case-insensitive; verify identifiers from raw bytes (R-S9).
- Never v2: save migrations are chained fill-defaults only.
- `docs/*` ships in-repo but stays OUT of the PCK (`docs/*` export exclusion).

## Engine discipline (rules 1–8, 11)
- Touch class per release is declared in the ADR; rate factor = branch, not
  expression term; default path must stay bit-identical (pacing 73038/13).
- `attunement` means P15 art attunement; meridian channels are `leyline_*`.
- Warded-style refusals name the gap. No silent fallbacks.

## Verification
- Exit codes authoritative; CSV (`docs/qa/p22/sweep_summary.csv`) wins over
  chat arithmetic (R-S8). New probes must demonstrate they can fail (R-S20).
- Record every release in `DECISIONS.md` + flight entries in
  `docs/agent/JOURNAL.md`.

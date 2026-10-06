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

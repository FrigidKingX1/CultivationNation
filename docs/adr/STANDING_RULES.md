# Standing Rules — Cultivation Nation
Status: LOCKED (append-only; new rules get the next number). Sources cited
per rule. Consolidated from the handoff, phase reports, and the 0.20.2–
0.22.0 audit trail.

## Process
R-S1 Exit codes are authoritative; PASS-line counts are advisory. (handoff 2.2)
R-S2 Never rewrite UTF-8 sources with PowerShell text cmdlets; byte-safe
     no-BOM writes only. (handoff 2.3.2)
R-S3 Headless tests pin root size + content scale to 1280x720. (handoff 2.3.3)
R-S4 Layout assertions use get_visible_rect(), never window pixels. (2.3.4)
R-S5 Scene-booting suites wipe saves/config before AND after. (2.3.5)
R-S6 Bind the live SubViewport texture at runtime; post-process samples the
     assigned texture + UV, never screen_texture. (P14)
R-S10 Leak-class fixes confirm headless >= 240s; one windowed soak per
     release at export when a human is present. (Q27)
R-S14 Never run soaks concurrently with suites; long soaks are [CONFIRM]. (Q27)
R-S16 Cross-file ledgers (report, DECISIONS, state.json, version) move
     together in ONE commit — phase-label collisions are renamed everywhere
     at once. (0.22.0)

## Engineering
R-S7  State your scale: every new power constant names its scale in-code. (0.21.0)
R-S8  CSV/sweep ground truth beats chat arithmetic. (0.22.0)
R-S9  Verify signatures against raw bytes; chat pastes are lossy. (0.22.0)
R-S11 Persistence guarantees are explicit: soul, guardians, records survive
      Samsara AND ascension. New persistent systems must state their
      persistence class in the ADR. (0.21.0 extension)
R-S12 Contract drift = same-commit contract update. Semantic-facade changes
      = rule-11 edit with justification; old-diorama internals churn in
      batch commits. (P23 churn protocol)
R-S13 Default-off opt-in systems preserve the measured baseline
      bit-identically; opt-in paths get their own recorded bands. (R-1
      pattern; now governs ADR-004)

# P16_AUDIT — Step 0 measurements (2026-10-04)

Method: temp play probe (`tests/probe_tmp.gd`, deleted after this report)
driving real UI handlers 4 lives at 1000x + screenshots per life, plus the
headless pacing diagnostic. All numbers measured.

## Offline mechanism (confirmed)

`saved_unix` is written on every save (`SaveManager.gd:25`) and read nowhere
for gains — the sole readers are the `compute_offline_gains` unit tests.
`Main._ready` loads and starts the sim fresh with zero catch-up. There is no
offline application to audit for bottleneck behavior; the feature is absent,
not broken. P16 Step 1 builds it.

## Pacing baseline (headless diagnostic, gated policy)

Full 50-realm clear: **70,738 ticks / 11 lives**, realm 3 at tick 584.
Proposed lower bands (tripwires against silent trivialization, ~40-45% below
measured): clear ≥ 30,000 ticks, lives ≥ 5, realm 3 ≥ 200 ticks. Uppers and
`fails == 0` unchanged. Rationale: a future change that halves clear time
should trip a band and force a conscious decision, not slide by.

## Play evidence (UI handlers, 1000x)

4 lives played end to end: origins, drill focus, sect founding (Quiet Lantern
Compact), 2 recruits on gather, map walking (dewfield_0, sympathy water
active), pill brewing (herbs 399→732), soul binding, talent buying, rebirths,
achievement unlocks (10/43 incl. tech/hunt/rebirth lines), teaching log lines
(drill hint fires naturally). Screenshot per life confirms the world renders
(Winter palette + snow + tribulation burst + banner visible mid-frame),
readiness button live (264% · Steady), sympathy/season segments live.
Systems engage through the real UI; no dead buttons encountered.

Two honest probe artifacts (not game bugs): the bot never breathes (stale
P10-era policy predates the P13 drill-yields-zero-Qi keystone), so it stalls
at realm 1 with empty Qi and dies of old age — expected under that policy.
Age-at-dump values above lifespan fractions are single-frame artifacts at
1000x (one headless frame spans decades). Neither implicates game code.

## Nothing dropped. P16 proceeds: offline (Step 1), lower bands (Step 2),
representation (Step 3).

# Pre-tag verification. READ-ONLY. Run before tag + push.
$projectPath = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $projectPath

Write-Host "== V1: HEAD / tree / ledger commit shape =="
git log -1 --oneline
git status --porcelain                 # expect EMPTY
git show --stat --format=oneline HEAD  # expect report + DECISIONS + project.godot + state.json ONLY (R-S16)

Write-Host "== V2: version consistency (all must read 0.26.0) =="
Select-String -Path project.godot -Pattern "config/version"
Select-String -Path state.json -Pattern "0\.26\.0" -Quiet
$report = Get-ChildItem -Filter "PHASE_*REPORT*.md" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Host "Newest report: $($report.Name)"
Select-String -Path $report.FullName -Pattern "0\.26\.0" -Quiet

Write-Host "== V3: export freshness (artifacts must postdate the ledger commit) =="
Write-Host "HEAD commit time: $(git log -1 --format=%ci HEAD)"
Get-ChildItem build\win | Select-Object Name, Length, LastWriteTime

Write-Host "== V4: sweep validity (CSV must postdate last code/content change) =="
Write-Host "Last scripts/data change: $(git log -1 --format=%ci -- scripts data project.godot)"
Get-Item docs\qa\p22\sweep_summary.csv | Select-Object LastWriteTime, Length

Write-Host "== V5: remote delta preview (what a push would ship) =="
git fetch origin 2>$null
git log --oneline origin/main..HEAD
git status -sb

Write-Host "== V6: tag state =="
git describe --tags --abbrev=0         # expect v0.25.0
git tag -l "v0.26*"

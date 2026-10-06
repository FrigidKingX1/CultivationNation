# Repo audit. READ-ONLY. Verdicts F2-F9 (audit loop closure, 1.0a).
# Run: powershell -ExecutionPolicy Bypass -File tools/repo_audit.ps1
# Exit 0 = all pass. F9 (CI) is informational until CI lands.
$projectPath = "E:\ClaudeATHome\Projects\Cultivation Nation"
Set-Location $projectPath
$fail = 0
function _check($cond, $name) {
  if ($cond) { Write-Host "PASS: $name" }
  else { Write-Host "FAIL: $name"; $script:fail += 1 }
}
Write-Host "== F2 LICENSE =="
_check (Test-Path -LiteralPath "$projectPath\LICENSE") "LICENSE file exists"
_check (((Get-Content -LiteralPath "$projectPath\LICENSE" -TotalCount 2) -join " ") -match "Copyright") "LICENSE names a holder"
Write-Host "== F3 attribution files =="
$refs = @("third_party\ChronoDK-Big", "addons\big_number", "addons\maaacks_game_template", "third_party\Maaack-LICENSE.txt", "third_party\KenneyStarter", "assets\music\title_lofi.ogg", "assets\music\game_lofi.ogg", "assets\music\triumph_lofi.ogg", "fonts\MaShanZheng-Regular.ttf", "fonts\Inter-Regular.ttf", "fonts\Inter-Bold.ttf", "fonts\OFL.txt")
foreach ($r in $refs) { _check (Test-Path -LiteralPath "$projectPath\$r") "in-tree: $r" }
Write-Host "== F4 README =="
$rm = Get-Content -LiteralPath "$projectPath\README.md" -Raw
_check ($rm -match "WASD" -and $rm -match "Right-click" -and $rm -match "\bV\b.*wander|wander.*\bV\b") "README teaches world verbs"
_check ($rm -match "suites, \d+ counted checks") "README states suite counts"
Write-Host "== F5 hardcoded machine paths =="
$hits = git grep -n "E:/ClaudeATHome\|E:\\ClaudeATHome\|dgc12" -- scripts tools data scenes project.godot export_presets.cfg 2>$null
_check (($null -eq $hits) -or ($hits.Count -eq 0)) "no machine paths in tracked game files"
if ($hits) { $hits | ForEach-Object { Write-Host "  STALE: $_" } }
Write-Host "== F6 conflict-rule help line =="
_check ((Get-Content -LiteralPath "$projectPath\scripts\Main.gd" -Raw) -match "one key, one action") "help documents rebind-replacement"
Write-Host "== F7 stale residue =="
$orphans = Get-ChildItem -LiteralPath $projectPath -Recurse -Filter "*.gd.uid" | Where-Object { -not (Test-Path -LiteralPath ($_.FullName -replace "\.uid$", "")) }
_check ($orphans.Count -eq 0) "no orphan .uid files"
$tmp = Get-ChildItem -LiteralPath "$projectPath\tools" -Filter "*tmp*" -ErrorAction SilentlyContinue
_check (($null -eq $tmp) -or ($tmp.Count -eq 0)) "no tmp probes in tools/"
Write-Host "== F8 weight =="
$mb = (Get-ChildItem -LiteralPath $projectPath -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "\\\.git\\" } | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host ("worktree (excl .git): {0:N1} MB" -f $mb)
_check ($mb -lt 1024) "worktree under 1GB"
Write-Host "== F9 CI =="
if (Test-Path -LiteralPath "$projectPath\.github") { _check ($true) "CI config present" }
else { Write-Host "INFO: no .github -- CI deferred (explicit, not dropped)" }
Write-Host "== F10 CHANGELOG =="
_check (Test-Path -LiteralPath "$projectPath\CHANGELOG.md") "CHANGELOG present"
if ($fail -eq 0) { Write-Host "REPO-AUDIT PASS" } else { Write-Host "REPO-AUDIT FAIL: $fail" }
exit $fail

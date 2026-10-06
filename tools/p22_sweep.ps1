# P22 verification sweep. Exit codes authoritative; PASS counts recorded for log diff.
# NEVER run p22_soak_save (or any soak mode) concurrently with this sweep.
$enginePath = "E:\Godot Game Engine\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$projectPath = "E:\ClaudeATHome\Projects\Cultivation Nation"
$outDir = Join-Path $projectPath "docs\qa\p22"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Output "=== Project gate ==="
& $enginePath --headless --path $projectPath --quit
$gateExit = $LASTEXITCODE
Write-Output ("Gate exit: " + $gateExit)

$suites = @(
  "self_test.gd","bench_test.gd","save_robustness_test.gd","bignum_test.gd",
  "prestige_test.gd","p19c_test.gd","p3_test.gd","p4_test.gd","p5_test.gd",
  "p6_test.gd","p7_test.gd","p8_test.gd","p9_test.gd","p10_test.gd",
  "p11_test.gd","p12_test.gd","p13_test.gd","p14_test.gd","p15_test.gd",
  "p16_test.gd","p17_test.gd","p21_test.gd","soak_test.gd",
  "guardians_test.gd","save_v12_migration_test.gd","p23_world_test.gd",
  "p24_presence_test.gd","p25_arena_test.gd","p26_stakes_test.gd"
)
$results = @()
foreach ($suite in $suites) {
  $logFile = Join-Path $outDir ($suite + ".log")
  Write-Output ("Running " + $suite + " ...")
  & $enginePath --headless --path $projectPath -s ("res://tests/" + $suite) *> $logFile
  $suiteExit = $LASTEXITCODE
  $passCount = @(Select-String -LiteralPath $logFile -Pattern "PASS:").Count
  $results += [pscustomobject]@{ Suite = $suite; Exit = $suiteExit; PassLines = $passCount }
  if ($suiteExit -ne 0) { Write-Output ("  !! " + $suite + " FAILED (exit " + $suiteExit + ") - see " + $logFile) }
}
$results | Format-Table -AutoSize | Out-String -Width 200 | Write-Output
$results | Export-Csv -NoTypeInformation -Path (Join-Path $outDir "sweep_summary.csv")
$failCount = @($results | Where-Object { $_.Exit -ne 0 }).Count
Write-Output ("Sweep complete: " + $results.Count + " suites, " + $failCount + " failures.")
if (($failCount -eq 0) -and ($gateExit -eq 0)) { exit 0 } else { exit 1 }

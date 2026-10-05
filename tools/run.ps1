# Cultivation Nation — autonomous runner (PowerShell 5.1 safe)
# Usage: powershell -ExecutionPolicy Bypass -File tools\run.ps1 [gate|test|import|export-win]
# (P13: Web target dropped; Windows only.)

$ErrorActionPreference = "Stop"
$Engine = "E:\Godot Game Engine\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
$Project = "E:\ClaudeATHome\Projects\Cultivation Nation"
$Mode = "gate"
if ($args.Count -ge 1) { $Mode = $args[0] }

function Invoke-Godot([string[]]$GodotArgs) {
  # Out-Host keeps engine spew on the console instead of captured into the
  # return value (a captured success stream turns $code into an array and
  # every mode misreports FAIL — caught in P13 when export-win ran green
  # but reported FAIL).
  & $Engine --path $Project @GodotArgs | Out-Host
  return $LASTEXITCODE
}

if ($Mode -eq "gate") {
  $code = Invoke-Godot @("--headless", "--quit")
  if ($code -ne 0) { Write-Host "GATE FAIL exit=$code"; exit 1 }
  Write-Host "GATE PASS"
  exit 0
}
if ($Mode -eq "test") {
  $code = Invoke-Godot @("--headless", "-s", "res://tests/self_test.gd")
  if ($code -ne 0) { Write-Host "TEST FAIL exit=$code"; exit 1 }
  Write-Host "TEST PASS"
  exit 0
}
if ($Mode -eq "import") {
  $code = Invoke-Godot @("--headless", "--import")
  exit $code
}
if ($Mode -eq "export-win") {
  New-Item -ItemType Directory -Path "$Project\build\win" -Force | Out-Null
  $code = Invoke-Godot @("--headless", "--export-release", "Windows", "$Project/build/win/CultivationNation.exe")
  if ($code -ne 0) { Write-Host "EXPORT FAIL exit=$code"; exit 1 }
  Write-Host "EXPORT PASS"
  exit 0
}
Write-Host "Unknown mode: $Mode"; exit 2

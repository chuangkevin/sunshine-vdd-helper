param([string]$InstallDir = 'C:\Program Files\SunshineVddHelper')

$ErrorActionPreference = 'SilentlyContinue'
$SunshineConfig = 'C:\Program Files\Sunshine\config\sunshine.conf'

function IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (IsAdmin)) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-InstallDir', $InstallDir)
  exit
}

function SetConfig($Key, $Value) {
  if (-not (Test-Path -LiteralPath $SunshineConfig)) { return }
  $lines = Get-Content -LiteralPath $SunshineConfig -Encoding UTF8
  $pattern = '^\s*' + [regex]::Escape($Key) + '\s*='
  $updated = foreach ($line in $lines) { if ($line -match $pattern) { "$Key = $Value" } else { $line } }
  Set-Content -LiteralPath $SunshineConfig -Value $updated -Encoding UTF8
}

schtasks /End /TN SunshineVddHelperWatch | Out-Null
schtasks /Delete /TN SunshineVddHelperWatch /F | Out-Null
schtasks /Delete /TN SunshineVddHelperInit /F | Out-Null

SetConfig 'global_prep_cmd' '[]'
SetConfig 'dd_configuration_option' 'disabled'

if (Get-Service SunshineService) { Restart-Service SunshineService -Force }

Write-Host 'Uninstall complete. The virtual display driver is still installed. Remove Virtual Display Driver from Device Manager if needed.'

param(
  [string]$InstallDir = 'C:\Program Files\SunshineVddHelper',
  [string]$SunshineConfig = 'C:\Program Files\Sunshine\config\sunshine.conf'
)

$ErrorActionPreference = 'SilentlyContinue'

function Test-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Set-ConfigValue([string]$Path, [string]$Key, [string]$Value) {
  if (-not (Test-Path -LiteralPath $Path)) { return }
  $lines = Get-Content -LiteralPath $Path -Encoding UTF8
  $pattern = '^\s*' + [regex]::Escape($Key) + '\s*='
  $updated = foreach ($item in $lines) {
    if ($item -match $pattern) { "$Key = $Value" } else { $item }
  }
  Set-Content -LiteralPath $Path -Value $updated -Encoding UTF8
}

if (-not (Test-Administrator)) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-InstallDir', $InstallDir, '-SunshineConfig', $SunshineConfig)
  exit
}

schtasks /End /TN SunshineVddHelperLocalDisplayWatch | Out-Null
schtasks /Delete /TN SunshineVddHelperLocalDisplayWatch /F | Out-Null
schtasks /Delete /TN SunshineVddHelperInit /F | Out-Null

Set-ConfigValue $SunshineConfig 'global_prep_cmd' '[]'
Set-ConfigValue $SunshineConfig 'dd_configuration_option' 'disabled'

if (Get-Service -Name SunshineService -ErrorAction SilentlyContinue) {
  Restart-Service -Name SunshineService -Force
}

Write-Host 'Sunshine VDD Helper configuration removed. VDD driver is left installed; remove it from Device Manager if desired.'

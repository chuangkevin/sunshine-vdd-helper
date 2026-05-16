param(
  [string]$InstallDir = 'C:\Program Files\SunshineVddHelper',
  [string]$SunshineConfig = 'C:\Program Files\Sunshine\config\sunshine.conf',
  [string]$SunshineLog = 'C:\Program Files\Sunshine\config\sunshine.log',
  [string]$Resolution = '1920x1080',
  [string]$RefreshRate = '60',
  [string]$VddVersion = '25.7.23'
)

$ErrorActionPreference = 'Stop'

$VddUrl = "https://github.com/VirtualDrivers/Virtual-Display-Driver/releases/download/$VddVersion/VDD.Control.$VddVersion.zip"
$MmtUrl = 'https://www.nirsoft.net/utils/multimonitortool-x64.zip'
$VddRoot = Join-Path $InstallDir 'VDD'
$VddZip = Join-Path $VddRoot "VDD.Control.$VddVersion.zip"
$VddExtract = Join-Path $VddRoot "VDD.Control.$VddVersion"
$VddInf = Join-Path $VddExtract 'SignedDrivers\x86\VDD\MttVDD.inf'
$Devcon = Join-Path $VddExtract 'Dependencies\devcon.exe'
$MmtDir = Join-Path $InstallDir 'MultiMonitorTool'
$MmtZip = Join-Path $MmtDir 'multimonitortool-x64.zip'
$MmtExe = Join-Path $MmtDir 'MultiMonitorTool.exe'
$VddSettingsDir = 'C:\VirtualDisplayDriver'
$VddSettings = Join-Path $VddSettingsDir 'vdd_settings.xml'
$StateDir = Join-Path $InstallDir 'state'

function Test-Administrator {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Directory([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function Set-ConfigValue([string]$Path, [string]$Key, [string]$Value) {
  $lines = @()
  if (Test-Path -LiteralPath $Path) {
    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
  }

  $pattern = '^\s*' + [regex]::Escape($Key) + '\s*='
  $line = "$Key = $Value"
  $found = $false
  $updated = foreach ($item in $lines) {
    if ($item -match $pattern) {
      $found = $true
      $line
    } else {
      $item
    }
  }

  if (-not $found) {
    $updated = @($updated) + $line
  }

  Set-Content -LiteralPath $Path -Value $updated -Encoding UTF8
}

function Get-SunshineVirtualDisplayId {
  if (-not (Test-Path -LiteralPath $SunshineLog)) {
    return $null
  }

  $raw = Get-Content -LiteralPath $SunshineLog -Raw -Encoding UTF8
  $matches = [regex]::Matches($raw, '(?s)"device_id"\s*:\s*"(?<id>\{[^"}]+\})".*?"friendly_name"\s*:\s*"(?<name>[^"]*)"')
  foreach ($match in $matches) {
    $name = $match.Groups['name'].Value
    if ($name -match 'Virtual Display Driver|MttVDD|MikeTheTech|IDD|VDD|Virtual') {
      return $match.Groups['id'].Value
    }
  }

  return $null
}

if (-not (Test-Administrator)) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-InstallDir', $InstallDir, '-SunshineConfig', $SunshineConfig, '-SunshineLog', $SunshineLog, '-Resolution', $Resolution, '-RefreshRate', $RefreshRate, '-VddVersion', $VddVersion)
  exit
}

Ensure-Directory $InstallDir
Ensure-Directory $StateDir
Ensure-Directory $VddRoot
Ensure-Directory $MmtDir

if (-not (Test-Path -LiteralPath $VddZip)) {
  Invoke-WebRequest -Uri $VddUrl -OutFile $VddZip
}
if (-not (Test-Path -LiteralPath $VddExtract)) {
  Expand-Archive -LiteralPath $VddZip -DestinationPath $VddExtract -Force
}
if (-not (Test-Path -LiteralPath $VddInf)) {
  throw "VDD driver INF not found: $VddInf"
}

if (-not (Test-Path -LiteralPath $MmtZip)) {
  Invoke-WebRequest -Uri $MmtUrl -OutFile $MmtZip
}
if (-not (Test-Path -LiteralPath $MmtExe)) {
  Expand-Archive -LiteralPath $MmtZip -DestinationPath $MmtDir -Force
}

Ensure-Directory $VddSettingsDir
@"
<?xml version='1.0' encoding='utf-8'?>
<vdd_settings>
  <monitors><count>1</count></monitors>
  <gpu><friendlyname>default</friendlyname></gpu>
  <global>
    <g_refresh_rate>60</g_refresh_rate>
    <g_refresh_rate>90</g_refresh_rate>
    <g_refresh_rate>120</g_refresh_rate>
    <g_refresh_rate>144</g_refresh_rate>
  </global>
  <resolutions>
    <resolution><width>1280</width><height>720</height><refresh_rate>60</refresh_rate></resolution>
    <resolution><width>1920</width><height>1080</height><refresh_rate>60</refresh_rate></resolution>
    <resolution><width>2560</width><height>1440</height><refresh_rate>60</refresh_rate></resolution>
    <resolution><width>3840</width><height>2160</height><refresh_rate>60</refresh_rate></resolution>
  </resolutions>
  <options>
    <CustomEdid>false</CustomEdid>
    <PreventSpoof>false</PreventSpoof>
    <EdidCeaOverride>false</EdidCeaOverride>
    <HardwareCursor>true</HardwareCursor>
    <SDR10bit>false</SDR10bit>
    <HDRPlus>false</HDRPlus>
    <logging>false</logging>
    <debuglogging>false</debuglogging>
  </options>
</vdd_settings>
"@ | Set-Content -LiteralPath $VddSettings -Encoding UTF8

pnputil /add-driver $VddInf /install | Out-Host
if (Test-Path -LiteralPath $Devcon) {
  & $Devcon install $VddInf Root\MttVDD | Out-Host
  & $Devcon rescan | Out-Host
}

$streamStateScript = Join-Path $InstallDir 'Sunshine-StreamState.ps1'
$watchScript = Join-Path $InstallDir 'Sunshine-LocalDisplayWatch.ps1'
$initScript = Join-Path $InstallDir 'Sunshine-VddInit.ps1'

@"
`$ErrorActionPreference = 'SilentlyContinue'
`$InstallDir = '$InstallDir'
`$StateDir = Join-Path `$InstallDir 'state'
`$ActiveFlag = Join-Path `$StateDir 'stream-active.flag'
`$LayoutFile = Join-Path `$StateDir 'physical-layout.cfg'
`$MmtExe = '$MmtExe'
New-Item -ItemType Directory -Force -Path `$StateDir | Out-Null

switch (`$args[0]) {
  'start' {
    if (Test-Path -LiteralPath `$MmtExe) {
      & `$MmtExe /SaveConfig `$LayoutFile | Out-Null
    }
    Set-Content -LiteralPath `$ActiveFlag -Value (Get-Date).ToString('o') -Encoding ASCII
  }
  'stop' {
    Remove-Item -LiteralPath `$ActiveFlag -Force
  }
}
exit 0
"@ | Set-Content -LiteralPath $streamStateScript -Encoding UTF8

@"
`$ErrorActionPreference = 'SilentlyContinue'
`$InstallDir = '$InstallDir'
`$StateDir = Join-Path `$InstallDir 'state'
`$ActiveFlag = Join-Path `$StateDir 'stream-active.flag'
`$LayoutFile = Join-Path `$StateDir 'physical-layout.cfg'
`$MonitorCsv = Join-Path `$StateDir 'monitors.csv'
`$LogFile = Join-Path `$StateDir 'local-display-watch.log'
`$MmtExe = '$MmtExe'
New-Item -ItemType Directory -Force -Path `$StateDir | Out-Null

function Write-WatchLog(`$Message) {
  Add-Content -LiteralPath `$LogFile -Value ("{0} {1}" -f (Get-Date).ToString('s'), `$Message) -Encoding UTF8
}

function Get-Monitors {
  if (-not (Test-Path -LiteralPath `$MmtExe)) { return @() }
  & `$MmtExe /scomma `$MonitorCsv | Out-Null
  if (Test-Path -LiteralPath `$MonitorCsv) { Import-Csv -LiteralPath `$MonitorCsv } else { @() }
}

function Is-Vdd(`$Monitor) {
  return ((`$Monitor.Adapter -match 'Virtual Display Driver') -or (`$Monitor.'Device ID' -match 'MttVDD') -or (`$Monitor.'Short Monitor ID' -match 'MTT1337') -or (`$Monitor.'Monitor Name' -match 'VDD'))
}

function Restore-PhysicalLayout {
  if (-not (Test-Path -LiteralPath `$MmtExe)) { return }

  `$monitors = @(Get-Monitors)
  `$physical = @(`$monitors | Where-Object { -not (Is-Vdd `$_) -and `$_.Disconnected -eq 'No' })
  if (`$physical.Count -eq 0) {
    DisplaySwitch.exe /extend | Out-Null
    Start-Sleep -Seconds 2
    `$monitors = @(Get-Monitors)
    `$physical = @(`$monitors | Where-Object { -not (Is-Vdd `$_) -and `$_.Disconnected -eq 'No' })
  }
  if (`$physical.Count -eq 0) { return }

  if (Test-Path -LiteralPath `$LayoutFile) {
    Write-WatchLog 'Restoring saved physical monitor layout'
    & `$MmtExe /LoadConfig `$LayoutFile | Out-Null
    Start-Sleep -Seconds 1
  } else {
    `$primary = `$physical | Where-Object { `$_.Primary -eq 'Yes' } | Select-Object -First 1
    if (-not `$primary) { `$primary = `$physical | Select-Object -First 1 }
    Write-WatchLog "No saved layout; setting `$(`$primary.Name) as primary"
    foreach (`$monitor in `$physical) { & `$MmtExe /enable `$monitor.Name | Out-Null }
    & `$MmtExe /SetPrimary `$primary.Name | Out-Null
  }

  `$monitors = @(Get-Monitors)
  `$activePhysical = `$monitors | Where-Object { -not (Is-Vdd `$_) -and `$_.Active -eq 'Yes' } | Select-Object -First 1
  if (`$activePhysical) {
    & `$MmtExe /MoveWindow `$activePhysical.Name All | Out-Null
  }
  foreach (`$vdd in (`$monitors | Where-Object { Is-Vdd `$_ })) {
    & `$MmtExe /disable `$vdd.Name | Out-Null
  }
}

Write-WatchLog 'watcher started'
while (`$true) {
  if (-not (Test-Path -LiteralPath `$ActiveFlag)) { Restore-PhysicalLayout }
  Start-Sleep -Seconds 10
}
"@ | Set-Content -LiteralPath $watchScript -Encoding UTF8

@"
`$ErrorActionPreference = 'SilentlyContinue'
`$SunshineConfig = '$SunshineConfig'
`$SunshineLog = '$SunshineLog'
function Set-ConfigValue(`$Path, `$Key, `$Value) {
  `$lines = @(); if (Test-Path -LiteralPath `$Path) { `$lines = Get-Content -LiteralPath `$Path -Encoding UTF8 }
  `$pattern = '^\s*' + [regex]::Escape(`$Key) + '\s*='; `$line = "`$Key = `$Value"; `$found = `$false
  `$updated = foreach (`$item in `$lines) { if (`$item -match `$pattern) { `$found = `$true; `$line } else { `$item } }
  if (-not `$found) { `$updated = @(`$updated) + `$line }
  Set-Content -LiteralPath `$Path -Value `$updated -Encoding UTF8
}
function Get-SunshineVirtualDisplayId {
  if (-not (Test-Path -LiteralPath `$SunshineLog)) { return `$null }
  `$raw = Get-Content -LiteralPath `$SunshineLog -Raw -Encoding UTF8
  `$matches = [regex]::Matches(`$raw, '(?s)"device_id"\s*:\s*"(?<id>\{[^"}]+\})".*?"friendly_name"\s*:\s*"(?<name>[^"]*)"')
  foreach (`$match in `$matches) { if (`$match.Groups['name'].Value -match 'Virtual Display Driver|MttVDD|MikeTheTech|IDD|VDD|Virtual') { return `$match.Groups['id'].Value } }
  return `$null
}
Start-Service -Name SunshineService
Restart-Service -Name SunshineService -Force
Start-Sleep -Seconds 8
`$id = Get-SunshineVirtualDisplayId
if (`$id) {
  Set-ConfigValue `$SunshineConfig 'output_name' `$id
  Set-ConfigValue `$SunshineConfig 'dd_configuration_option' 'ensure_primary'
  Set-ConfigValue `$SunshineConfig 'dd_resolution_option' 'manual'
  Set-ConfigValue `$SunshineConfig 'dd_manual_resolution' '$Resolution'
  Set-ConfigValue `$SunshineConfig 'dd_refresh_rate_option' 'manual'
  Set-ConfigValue `$SunshineConfig 'dd_manual_refresh_rate' '$RefreshRate'
  Set-ConfigValue `$SunshineConfig 'dd_hdr_option' 'disabled'
  Set-ConfigValue `$SunshineConfig 'dd_config_revert_on_disconnect' 'enabled'
  Set-ConfigValue `$SunshineConfig 'dd_config_revert_delay' '1500'
  Restart-Service -Name SunshineService -Force
}
"@ | Set-Content -LiteralPath $initScript -Encoding UTF8

$prepCmd = '[{"do":"powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"' + ($streamStateScript -replace '\\', '\\') + '\" start","undo":"powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"' + ($streamStateScript -replace '\\', '\\') + '\" stop"}]'
Set-ConfigValue $SunshineConfig 'global_prep_cmd' $prepCmd
Set-ConfigValue $SunshineConfig 'dd_configuration_option' 'ensure_primary'
Set-ConfigValue $SunshineConfig 'dd_resolution_option' 'manual'
Set-ConfigValue $SunshineConfig 'dd_manual_resolution' $Resolution
Set-ConfigValue $SunshineConfig 'dd_refresh_rate_option' 'manual'
Set-ConfigValue $SunshineConfig 'dd_manual_refresh_rate' $RefreshRate
Set-ConfigValue $SunshineConfig 'dd_hdr_option' 'disabled'
Set-ConfigValue $SunshineConfig 'dd_config_revert_on_disconnect' 'enabled'
Set-ConfigValue $SunshineConfig 'dd_config_revert_delay' '1500'

$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName 'SunshineVddHelperInit' -Action (New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$initScript`"") -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Register-ScheduledTask -TaskName 'SunshineVddHelperLocalDisplayWatch' -Action (New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watchScript`"") -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

Restart-Service -Name SunshineService -Force
Start-Sleep -Seconds 8
$virtualId = Get-SunshineVirtualDisplayId
if ($virtualId) {
  Set-ConfigValue $SunshineConfig 'output_name' $virtualId
  Restart-Service -Name SunshineService -Force
}
Start-ScheduledTask -TaskName 'SunshineVddHelperLocalDisplayWatch'

Write-Host 'Sunshine VDD Helper installation complete.'
if ($virtualId) { Write-Host "Sunshine virtual display id: $virtualId" } else { Write-Warning 'Virtual display id was not found yet. Reboot once, then run this installer again if Sunshine cannot stream.' }

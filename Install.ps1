param(
  [string]$InstallDir = 'C:\Program Files\SunshineVddHelper',
  [string]$Resolution = 'auto',
  [string]$RefreshRate = '60'
)

$ErrorActionPreference = 'Stop'
$SunshineConfig = 'C:\Program Files\Sunshine\config\sunshine.conf'
$SunshineLog = 'C:\Program Files\Sunshine\config\sunshine.log'
$VddVersion = '25.7.23'
$VddUrl = "https://github.com/VirtualDrivers/Virtual-Display-Driver/releases/download/$VddVersion/VDD.Control.$VddVersion.zip"
$MmtUrl = 'https://www.nirsoft.net/utils/multimonitortool-x64.zip'

function IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (IsAdmin)) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-InstallDir', $InstallDir, '-Resolution', $Resolution, '-RefreshRate', $RefreshRate)
  exit
}

function EnsureDir($Path) {
  if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Force -Path $Path | Out-Null }
}

function SetConfig($Key, $Value) {
  $lines = @()
  if (Test-Path -LiteralPath $SunshineConfig) { $lines = Get-Content -LiteralPath $SunshineConfig -Encoding UTF8 }
  $pattern = '^\s*' + [regex]::Escape($Key) + '\s*='
  $found = $false
  $updated = foreach ($line in $lines) {
    if ($line -match $pattern) { $found = $true; "$Key = $Value" } else { $line }
  }
  if (-not $found) { $updated = @($updated) + "$Key = $Value" }
  Set-Content -LiteralPath $SunshineConfig -Value $updated -Encoding UTF8
}

function GetVddId {
  if (-not (Test-Path -LiteralPath $SunshineLog)) { return $null }
  $raw = Get-Content -LiteralPath $SunshineLog -Raw -Encoding UTF8
  $matches = [regex]::Matches($raw, '(?s)"device_id"\s*:\s*"(?<id>\{[^"}]+\})".*?"friendly_name"\s*:\s*"(?<name>[^"]*)"')
  foreach ($m in $matches) {
    if ($m.Groups['name'].Value -match 'Virtual Display Driver|MttVDD|MikeTheTech|IDD|VDD|Virtual') { return $m.Groups['id'].Value }
  }
  $null
}

EnsureDir $InstallDir
EnsureDir (Join-Path $InstallDir 'state')
EnsureDir (Join-Path $InstallDir 'VDD')
EnsureDir (Join-Path $InstallDir 'MultiMonitorTool')
EnsureDir 'C:\VirtualDisplayDriver'

$vddZip = Join-Path $InstallDir "VDD\VDD.Control.$VddVersion.zip"
$vddDir = Join-Path $InstallDir "VDD\VDD.Control.$VddVersion"
$vddInf = Join-Path $vddDir 'SignedDrivers\x86\VDD\MttVDD.inf'
$devcon = Join-Path $vddDir 'Dependencies\devcon.exe'
$mmtZip = Join-Path $InstallDir 'MultiMonitorTool\multimonitortool-x64.zip'
$mmtExe = Join-Path $InstallDir 'MultiMonitorTool\MultiMonitorTool.exe'

if (-not (Test-Path -LiteralPath $vddZip)) { Invoke-WebRequest -Uri $VddUrl -OutFile $vddZip }
if (-not (Test-Path -LiteralPath $vddInf)) { Expand-Archive -LiteralPath $vddZip -DestinationPath $vddDir -Force }
if (-not (Test-Path -LiteralPath $mmtZip)) { Invoke-WebRequest -Uri $MmtUrl -OutFile $mmtZip }
if (-not (Test-Path -LiteralPath $mmtExe)) { Expand-Archive -LiteralPath $mmtZip -DestinationPath (Split-Path $mmtExe) -Force }

@'
<?xml version='1.0' encoding='utf-8'?>
<vdd_settings>
  <monitors><count>1</count></monitors>
  <gpu><friendlyname>default</friendlyname></gpu>
  <global><g_refresh_rate>60</g_refresh_rate><g_refresh_rate>90</g_refresh_rate><g_refresh_rate>120</g_refresh_rate><g_refresh_rate>144</g_refresh_rate></global>
  <resolutions>
    <resolution><width>640</width><height>480</height><refresh_rate>60</refresh_rate></resolution>
    <resolution><width>1280</width><height>720</height><refresh_rate>60</refresh_rate></resolution>
    <resolution><width>1920</width><height>1080</height><refresh_rate>60</refresh_rate></resolution>
    <resolution><width>2400</width><height>1080</height><refresh_rate>60</refresh_rate></resolution>
    <resolution><width>2556</width><height>1179</height><refresh_rate>60</refresh_rate></resolution>
    <resolution><width>2560</width><height>1440</height><refresh_rate>60</refresh_rate></resolution>
    <resolution><width>3200</width><height>1440</height><refresh_rate>60</refresh_rate></resolution>
    <resolution><width>3840</width><height>2160</height><refresh_rate>60</refresh_rate></resolution>
  </resolutions>
  <options><CustomEdid>false</CustomEdid><PreventSpoof>false</PreventSpoof><EdidCeaOverride>false</EdidCeaOverride><HardwareCursor>true</HardwareCursor><SDR10bit>false</SDR10bit><HDRPlus>false</HDRPlus><logging>false</logging><debuglogging>false</debuglogging></options>
</vdd_settings>
'@ | Set-Content -LiteralPath 'C:\VirtualDisplayDriver\vdd_settings.xml' -Encoding UTF8

pnputil /add-driver $vddInf /install | Out-Host
if (Test-Path -LiteralPath $devcon) { & $devcon install $vddInf Root\MttVDD | Out-Host; & $devcon rescan | Out-Host }

$streamScript = Join-Path $InstallDir 'StreamState.ps1'
$watchScript = Join-Path $InstallDir 'LocalDisplayWatch.ps1'
$initScript = Join-Path $InstallDir 'VddInit.ps1'

@"
`$StateDir = '$InstallDir\state'
`$Flag = Join-Path `$StateDir 'stream-active.flag'
`$Layout = Join-Path `$StateDir 'physical-layout.cfg'
`$Mmt = '$mmtExe'
New-Item -ItemType Directory -Force -Path `$StateDir | Out-Null
if (`$args[0] -eq 'start') { & `$Mmt /SaveConfig `$Layout | Out-Null; Set-Content `$Flag (Get-Date).ToString('o') }
if (`$args[0] -eq 'stop') { Remove-Item `$Flag -Force -ErrorAction SilentlyContinue }
exit 0
"@ | Set-Content -LiteralPath $streamScript -Encoding UTF8

@"
`$ErrorActionPreference = 'SilentlyContinue'
`$StateDir = '$InstallDir\state'
`$Flag = Join-Path `$StateDir 'stream-active.flag'
`$Layout = Join-Path `$StateDir 'physical-layout.cfg'
`$Csv = Join-Path `$StateDir 'monitors.csv'
`$Mmt = '$mmtExe'
function Mons { & `$Mmt /scomma `$Csv | Out-Null; if (Test-Path `$Csv) { Import-Csv `$Csv } else { @() } }
function IsVdd(`$m) { (`$m.Adapter -match 'Virtual Display Driver') -or (`$m.'Device ID' -match 'MttVDD') -or (`$m.'Short Monitor ID' -match 'MTT1337') -or (`$m.'Monitor Name' -match 'VDD') }
while (`$true) {
  if (-not (Test-Path `$Flag)) {
    `$mon = @(Mons)
    `$physical = @(`$mon | Where-Object { -not (IsVdd `$_) -and `$_.Disconnected -eq 'No' })
    if (`$physical.Count -eq 0) { DisplaySwitch.exe /extend | Out-Null; Start-Sleep 2; `$mon = @(Mons); `$physical = @(`$mon | Where-Object { -not (IsVdd `$_) -and `$_.Disconnected -eq 'No' }) }
    if (`$physical.Count -gt 0) {
      if (Test-Path `$Layout) { & `$Mmt /LoadConfig `$Layout | Out-Null } else { & `$Mmt /SetPrimary `$physical[0].Name | Out-Null }
      Start-Sleep 1
      `$mon = @(Mons)
      `$active = `$mon | Where-Object { -not (IsVdd `$_) -and `$_.Active -eq 'Yes' } | Select-Object -First 1
      if (`$active) { & `$Mmt /MoveWindow `$active.Name All | Out-Null }
      foreach (`$v in (`$mon | Where-Object { IsVdd `$_ })) { & `$Mmt /disable `$v.Name | Out-Null }
    }
  }
  Start-Sleep 10
}
"@ | Set-Content -LiteralPath $watchScript -Encoding UTF8

@"
`$SunshineConfig = '$SunshineConfig'
`$SunshineLog = '$SunshineLog'
function SetConfig(`$Key, `$Value) { `$lines = Get-Content `$SunshineConfig -Encoding UTF8; `$p = '^\s*' + [regex]::Escape(`$Key) + '\s*='; `$found = `$false; `$out = foreach (`$l in `$lines) { if (`$l -match `$p) { `$found = `$true; "`$Key = `$Value" } else { `$l } }; if (-not `$found) { `$out = @(`$out) + "`$Key = `$Value" }; Set-Content `$SunshineConfig `$out -Encoding UTF8 }
function GetVddId { `$raw = Get-Content `$SunshineLog -Raw -Encoding UTF8; `$ms = [regex]::Matches(`$raw, '(?s)"device_id"\s*:\s*"(?<id>\{[^"}]+\})".*?"friendly_name"\s*:\s*"(?<name>[^"]*)"'); foreach (`$m in `$ms) { if (`$m.Groups['name'].Value -match 'Virtual Display Driver|MttVDD|MikeTheTech|IDD|VDD|Virtual') { return `$m.Groups['id'].Value } } }
Restart-Service SunshineService -Force
Start-Sleep 8
`$id = GetVddId
if (`$id) {
  SetConfig 'output_name' `$id
  SetConfig 'dd_configuration_option' 'ensure_primary'
  SetConfig 'dd_resolution_option' 'auto'
  SetConfig 'dd_refresh_rate_option' 'auto'
  SetConfig 'dd_hdr_option' 'disabled'
  Restart-Service SunshineService -Force
}
"@ | Set-Content -LiteralPath $initScript -Encoding UTF8

$prep = '[{"do":"powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"' + ($streamScript -replace '\\', '\\') + '\" start","undo":"powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"' + ($streamScript -replace '\\', '\\') + '\" stop"}]'
SetConfig 'global_prep_cmd' $prep
SetConfig 'dd_configuration_option' 'ensure_primary'
if ($Resolution -eq 'auto') {
  SetConfig 'dd_resolution_option' 'auto'
} else {
  SetConfig 'dd_resolution_option' 'manual'
  SetConfig 'dd_manual_resolution' $Resolution
}
if ($RefreshRate -eq 'auto') {
  SetConfig 'dd_refresh_rate_option' 'auto'
} else {
  SetConfig 'dd_refresh_rate_option' 'manual'
  SetConfig 'dd_manual_refresh_rate' $RefreshRate
}
SetConfig 'dd_hdr_option' 'disabled'
SetConfig 'dd_config_revert_on_disconnect' 'enabled'
SetConfig 'dd_config_revert_delay' '1500'

$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
Register-ScheduledTask -TaskName 'SunshineVddHelperInit' -Action (New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$initScript`"") -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Register-ScheduledTask -TaskName 'SunshineVddHelperWatch' -Action (New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watchScript`"") -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

Restart-Service SunshineService -Force
Start-Sleep 8
$id = GetVddId
if ($id) { SetConfig 'output_name' $id; Restart-Service SunshineService -Force }
Start-ScheduledTask -TaskName 'SunshineVddHelperWatch'

Write-Host 'Install complete. Test Sunshine streaming with Moonlight.'

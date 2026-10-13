<#
.SYNOPSIS
  Records the HealthTick demo video from a USB-connected Android phone, end to end.

.DESCRIPTION
  1. Checks the phone (adb), Docker Postgres and that port 3000 is free; starts the API itself; resets demo progress.
  2. Sets phone demo settings (show touches, Do Not Disturb, stay awake) and restores them afterwards.
  3. Runs integration_test/demo_walkthrough_test.dart with `flutter drive --profile` and reads its output live:
       DEMO_MARKER:START            -> start scrcpy recording to demo/demo_raw.mp4
       DEMO_MARKER:REALTIME         -> npm run demo:set-node-count -- --level insider_l2 --count 5
       DEMO_MARKER:REALTIME_REVERT  -> npm run demo:set-node-count -- --level insider_l2 --count 3
       DEMO_MARKER:STOP_API         -> stop the API, wait 6 s, start it again
       DEMO_MARKER:SHOT:<name>      -> save a verification screenshot to demo/shots/<name>.png
       DEMO_MARKER:DONE             -> stop the recorder cleanly (window close -> mp4 finalised)
  4. Stops the API, restores phone settings, resets demo progress and prints the video duration and size.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\record-demo.ps1
  powershell -ExecutionPolicy Bypass -File scripts\record-demo.ps1 -Device R58M123ABC
#>
param(
  [string]$Device = '',
  [string]$OutputName = 'demo_raw.mp4'
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Backend = Join-Path $Root 'user_journey_backend'
$App = Join-Path $Root 'user_journey'
$DemoDir = Join-Path $Root 'demo'
$ShotDir = Join-Path $DemoDir 'shots'
$Output = Join-Path $DemoDir $OutputName
New-Item -ItemType Directory -Force $DemoDir, $ShotDir | Out-Null
$RunLog = Join-Path $DemoDir 'drive.log'
Set-Content -Path $RunLog -Value '' -Encoding utf8

$Adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path $Adb)) { throw "adb not found at $Adb" }
$env:ADB = $Adb # scrcpy uses the same adb as the SDK (avoids two adb servers fighting)

$Scrcpy = (Get-Command scrcpy -ErrorAction SilentlyContinue).Source
if (-not $Scrcpy) {
  $Scrcpy = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') -Recurse -Filter scrcpy.exe -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
}
if (-not $Scrcpy) { throw 'scrcpy not found (winget install --id Genymobile.scrcpy -e)' }

function Log([string]$Message) {
  $line = "[record-demo $(Get-Date -Format HH:mm:ss)] $Message"
  Write-Host $line -ForegroundColor Cyan
  Add-Content -Path $RunLog -Value $line -Encoding utf8
}

function Invoke-Adb([string[]]$AdbArgs) { & $Adb -s $Device @AdbArgs }

# ---------------------------------------------------------------- pre-flight
if (-not $Device) {
  $Device = (& $Adb devices | Select-String "`tdevice$" | ForEach-Object { $_.ToString().Split("`t")[0] } |
      Where-Object { $_ -notlike 'emulator-*' } | Select-Object -First 1)
}
if (-not $Device) { throw 'No USB phone found in "adb devices" (connect it and accept the USB debugging prompt).' }
if (-not (& $Adb devices | Select-String "^$([regex]::Escape($Device))`tdevice$")) {
  throw "Device $Device is not connected/authorised in ""adb devices""."
}
Log "Phone: $Device ($(Invoke-Adb @('shell','getprop','ro.product.model')))"

$pg = docker ps --filter 'name=healthtick-postgres' --filter 'health=healthy' --format '{{.Names}}'
if (-not $pg) { throw 'Postgres is not running/healthy: run "docker compose up -d" first.' }
if (Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue) {
  throw 'Port 3000 is already in use. Stop the running API first (this script starts its own).'
}

# ---------------------------------------------------------------- API process (owned by this script)
$script:ApiProcess = $null
$script:ApiStarts = 0
function Start-Api {
  $script:ApiStarts++
  $script:ApiProcess = Start-Process -FilePath 'node' -ArgumentList 'node_modules/tsx/dist/cli.mjs', 'src/server.ts' `
    -WorkingDirectory $Backend -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $DemoDir "api$($script:ApiStarts).log") `
    -RedirectStandardError (Join-Path $DemoDir "api$($script:ApiStarts).err.log")
  for ($i = 0; $i -lt 60; $i++) {
    try { if ((Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 http://localhost:3000/health).StatusCode -eq 200) { Log 'API is up'; return } } catch {}
    Start-Sleep -Milliseconds 500
  }
  throw 'API did not become healthy within 30 s'
}
function Stop-Api {
  if ($script:ApiProcess -and -not $script:ApiProcess.HasExited) {
    # tsx runs the server in a child process: kill the whole tree.
    & taskkill /PID $script:ApiProcess.Id /T /F | Out-Null
    Log 'API stopped'
  }
  $script:ApiProcess = $null
}
function Invoke-Npm([string[]]$NpmArgs) {
  Push-Location $Backend
  try { & npm.cmd @NpmArgs 2>&1 | ForEach-Object { Log "npm: $_" } } finally { Pop-Location }
}

# ---------------------------------------------------------------- recorder
$script:Recorder = $null
function Start-Recorder {
  if ($script:Recorder) { return }
  if (Test-Path $Output) { Remove-Item $Output }
  # Start-Process joins arguments with spaces without quoting, so quote values that may contain spaces.
  $scrcpyArgs = '-s {0} --record "{1}" --no-audio --window-title "HealthTick demo recording"' -f $Device, $Output
  $script:Recorder = Start-Process -FilePath $Scrcpy -PassThru -ArgumentList $scrcpyArgs `
    -RedirectStandardOutput (Join-Path $DemoDir 'scrcpy.log') -RedirectStandardError (Join-Path $DemoDir 'scrcpy.err.log')
  Start-Sleep -Seconds 2
  if ($script:Recorder.HasExited) { throw "scrcpy exited immediately: $(Get-Content (Join-Path $DemoDir 'scrcpy.err.log') -Raw)" }
  Log "Recording to $Output"
}
function Stop-Recorder {
  if (-not $script:Recorder) { return }
  if (-not $script:Recorder.HasExited) {
    # Closing the window makes scrcpy finish the mp4 properly (a hard kill would corrupt it).
    $null = $script:Recorder.CloseMainWindow()
    if (-not $script:Recorder.WaitForExit(20000)) {
      Log 'scrcpy did not exit after window close; forcing it (video may be damaged)'
      Stop-Process -Id $script:Recorder.Id -Force
    }
  }
  Log 'Recording stopped'
  $script:Recorder = $null
}

function Save-Shot([string]$Name) {
  $remote = "/sdcard/healthtick_demo_$Name.png"
  Invoke-Adb @('shell', 'screencap', '-p', $remote) | Out-Null
  Invoke-Adb @('pull', $remote, (Join-Path $ShotDir "$Name.png")) | Out-Null
  Invoke-Adb @('shell', 'rm', $remote) | Out-Null
}

# ---------------------------------------------------------------- phone settings (restored in finally)
$saved = @{
  showTouches = (Invoke-Adb @('shell', 'settings', 'get', 'system', 'show_touches')).Trim()
  zenMode     = (Invoke-Adb @('shell', 'settings', 'get', 'global', 'zen_mode')).Trim()
  stayOn      = (Invoke-Adb @('shell', 'settings', 'get', 'global', 'stay_on_while_plugged_in')).Trim()
}
Log "Saved phone settings: $($saved | ConvertTo-Json -Compress)"
function Restore-PhoneSettings {
  function Value($v, $default) { if ($v -and $v -ne 'null') { $v } else { $default } }
  Invoke-Adb @('shell', 'settings', 'put', 'system', 'show_touches', (Value $saved.showTouches '0')) | Out-Null
  Invoke-Adb @('shell', 'settings', 'put', 'global', 'zen_mode', (Value $saved.zenMode '0')) | Out-Null
  Invoke-Adb @('shell', 'settings', 'put', 'global', 'stay_on_while_plugged_in', (Value $saved.stayOn '0')) | Out-Null
  Log 'Phone settings restored'
}

$driveExit = 1
try {
  Invoke-Adb @('reverse', 'tcp:3000', 'tcp:3000') | Out-Null
  Invoke-Adb @('shell', 'settings', 'put', 'system', 'show_touches', '1') | Out-Null
  Invoke-Adb @('shell', 'settings', 'put', 'global', 'zen_mode', '1') | Out-Null
  Invoke-Adb @('shell', 'svc', 'power', 'stayon', 'usb') | Out-Null
  Invoke-Adb @('shell', 'input', 'keyevent', 'KEYCODE_WAKEUP') | Out-Null

  Start-Api
  Invoke-Npm @('run', '-s', 'progress:reset')
  Invoke-Npm @('run', '-s', 'demo:set-node-count', '--', '--level', 'insider_l2', '--count', '3')

  Log 'Building and running the walkthrough (profile mode)...'
  Push-Location $App
  $ErrorActionPreference = 'Continue' # flutter writes progress to stderr
  try {
    & flutter drive --profile --driver=test_driver/integration_test.dart `
      --target=integration_test/demo_walkthrough_test.dart -d $Device `
      --dart-define=API_BASE_URL=http://localhost:3000 2>&1 | ForEach-Object {
      $line = "$_"
      Write-Host $line
      Add-Content -Path $RunLog -Value $line -Encoding utf8
      if ($line -match 'DEMO_MARKER:([A-Z_]+)(?::(\S+))?') {
        $markerName = $Matches[1]; $arg = $Matches[2]
        switch ($markerName) {
          'START' { Start-Recorder }
          'REALTIME' { Log 'Real time: 5 Insider nodes'; Invoke-Npm @('run', '-s', 'demo:set-node-count', '--', '--level', 'insider_l2', '--count', '5') }
          'REALTIME_REVERT' { Log 'Real time: back to 3'; Invoke-Npm @('run', '-s', 'demo:set-node-count', '--', '--level', 'insider_l2', '--count', '3') }
          'STOP_API' { Stop-Api; Start-Sleep -Seconds 6; Start-Api }
          'SHOT' { Save-Shot $arg }
          'DONE' { Start-Sleep -Seconds 1; Stop-Recorder }
        }
      }
    }
    $driveExit = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = 'Stop'
    Pop-Location
  }
  Log "flutter drive exit code: $driveExit"
} finally {
  Stop-Recorder
  Restore-PhoneSettings
  Stop-Api
  try { Invoke-Npm @('run', '-s', 'progress:reset') } catch { Log "progress:reset failed: $_" }
  try { Invoke-Npm @('run', '-s', 'demo:set-node-count', '--', '--level', 'insider_l2', '--count', '3') } catch {}
}

# ---------------------------------------------------------------- report
if (Test-Path $Output) {
  $file = Get-Item $Output
  $shell = New-Object -ComObject Shell.Application
  $folder = $shell.Namespace($file.DirectoryName)
  $item = $folder.ParseName($file.Name)
  $duration = $folder.GetDetailsOf($item, 27)
  Log ("Video: {0}  duration {1}  size {2:N1} MB" -f $file.FullName, $duration, ($file.Length / 1MB))
} else {
  Log 'No video file was produced'
}
exit $driveExit

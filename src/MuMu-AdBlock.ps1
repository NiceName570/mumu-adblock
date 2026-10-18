[CmdletBinding()]
param(
    [ValidateSet('Menu','Apply','Undo','Check')][string]$Action = 'Menu',
    [string]$ManagerPath,
    [ValidateRange(-1,9999)][int]$VmIndex = -1,
    [switch]$NoPause,
    [switch]$NoRestart
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'MuMu.Core.psm1') -Force
$homeDir = Join-Path $env:LOCALAPPDATA 'MuMu-AdBlock'
[void](New-Item -ItemType Directory -Force -Path $homeDir)
$log = Join-Path $homeDir ('run-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.log')
$exitCode = 0
$transcribing = $false
function Manager([string[]]$Arguments) { Invoke-Native $script:ManagerPath $Arguments }
function Shell([string]$Command) { Manager @('adb','--vmindex',"$script:VmIndex",'--cmd',('shell ' + $Command)) }
function Root-Shell([string]$Command) { Shell ('su -c "' + $Command + '"') }
function Confirm-Change([string]$Message) {
    if ($NoRestart) { throw "$Message Automatic restart/start was disabled. No restart performed." }
    return ((Read-Host ($Message + ' [y/N]')) -match '^(y|yes)$')
}
function Save-State($State) {
    $temp = $script:statePath + '.tmp'
    $State | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding UTF8
    Move-Item -LiteralPath $temp -Destination $script:statePath -Force
}
function Ensure-Root {
    $boot = Shell 'getprop sys.boot_completed'
    if ($boot.Trim() -ne '1') {
        if (-not (Confirm-Change 'This instance is not ready. Start it (or restart it if stuck)? Save any work first.')) { throw 'Start/restart cancelled.' }
        $infoNow = (Manager @('info','--vmindex',"$VmIndex") | ConvertFrom-Json).PSObject.Properties | Select-Object -First 1
        $verb = if ($infoNow.Value.is_process_started) { 'restart' } else { 'launch' }
        [void](Manager @('control','--vmindex',"$VmIndex",$verb))
    }
    $deadline = (Get-Date).AddSeconds(120)
    $rootRestartAttempted = $false
    do {
        try {
            if ((Root-Shell 'id') -match 'uid=0\(root\)') { return }
        } catch { }
        # A ready system without su needs one explicitly approved restart.
        if ((Get-Date) -gt $deadline) { throw 'Root did not become ready. Check MuMu root settings and rerun. Firewall protection remains installed.' }
        if ((Shell 'getprop sys.boot_completed').Trim() -eq '1' -and -not $rootRestartAttempted) {
            if (-not (Confirm-Change 'Root is configured but not available yet. Restart this MuMu instance now? Save your game first.')) { throw 'Restart cancelled; rerun after restarting MuMu.' }
            $rootRestartAttempted = $true
            [void](Manager @('control','--vmindex',"$VmIndex",'restart'))
            Start-Sleep -Seconds 3
        } else { Start-Sleep -Seconds 2 }
    } while ($true)
}
function Verify-Widgets([string]$Expected) {
    $dump = Shell 'dumpsys package com.mumu.store'
    foreach ($class in Get-WidgetComponents) {
        $stateNow = Get-ComponentState $dump $class
        Write-Host "  $class : $stateNow"
        if ($Expected -and $stateNow -ne $Expected) { throw "Verification failed for $class ($stateNow)." }
    }
    return $dump
}
try {
    Start-Transcript -LiteralPath $log | Out-Null
    $transcribing = $true
    Write-Host 'MuMu AdBlock 2.0 - startup ads, LAN protection and home-screen widgets'
    Write-Host 'No apps deleted. No launcher data cleared. No login/payment changes.'
    if ($Action -eq 'Menu') {
        Write-Host "`n1. Apply protection`n2. Undo this tool`n3. Check current status`n4. Exit"
        switch (Read-Host 'Choose') {
            '1' { $Action = 'Apply' }
            '2' { $Action = 'Undo' }
            '3' { $Action = 'Check' }
            default { return }
        }
    }
    if (-not $ManagerPath) {
        $found = @(Find-MuMuManager)
        if ($found.Count -eq 1) { $ManagerPath = $found[0] }
        else { $ManagerPath = (Read-Host 'Paste the full path to your installed MuMuManager.exe').Trim('"') }
    }
    if (-not (Test-Path -LiteralPath $ManagerPath -PathType Leaf) -or (Split-Path $ManagerPath -Leaf) -ne 'MuMuManager.exe') { throw 'MuMuManager.exe not found. Install MuMu or select its manager executable.' }
    $ManagerPath = (Resolve-Path -LiteralPath $ManagerPath).Path
    $instances = Manager @('info','--vmindex','all') | ConvertFrom-Json
    $entries = @($instances.PSObject.Properties | Where-Object { $_.Name -match '^\d+$' })
    if ($entries.Count -eq 0) { throw 'No MuMu instances found.' }
    if ($VmIndex -lt 0) {
        if ($entries.Count -eq 1) { $VmIndex = [int]$entries[0].Name }
        else {
            Write-Host "`nChoose which emulator to change (only this instance will be changed):"
            foreach ($entry in $entries) { Write-Host ("  {0}: {1} (Android {2}, process running: {3})" -f $entry.Name,$entry.Value.name,$entry.Value.android_version,$entry.Value.is_process_started) }
            $choice = Read-Host 'Instance number'
            if ($choice -notmatch '^\d+$') { throw 'Invalid instance number.' }
            $VmIndex = [int]$choice
        }
    }
    if (-not ($entries.Name -contains "$VmIndex")) { throw 'Selected instance does not exist.' }
    Write-Host "Selected instance $VmIndex using $ManagerPath"
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $key = ([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($ManagerPath.ToLowerInvariant())))).Replace('-','').Substring(0,16) } finally { $hash.Dispose() }
    $statePath = Join-Path $homeDir ("state-$key-$VmIndex.json")
    if ($Action -eq 'Check') {
        Write-Host 'Root setting:'
        Write-Host (Manager @('setting','--vmindex',"$VmIndex",'--key','root_permission'))
        Write-Host 'Root shell:'
        Write-Host (Root-Shell 'id')
        [void](Verify-Widgets '')
        Get-NetFirewallRule -ErrorAction SilentlyContinue | Where-Object DisplayName -like 'MuMu-AdBlock:*' | Select-Object DisplayName,Enabled,Direction,Action | Format-Table | Out-Host
        return
    }
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Run mumu_adblock.exe and accept the Windows administrator prompt.' }
    $firewall = Join-Path $PSScriptRoot 'block_mumu_ads.ps1'
    if (-not (Test-Path $firewall)) { $firewall = Join-Path $PSScriptRoot '..\block_mumu_ads.ps1' }
    $ps = Join-Path $PSHOME 'powershell.exe'
    $state = $null
    if (Test-Path $statePath) { $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json }
    if ($Action -eq 'Apply') {
        # Keep network protection even if this emulator version lacks the widgets.
        Write-Host "`nApplying startup-ad network block and inbound LAN-port protection..."
        Write-Host (Invoke-Native $ps @('-NoProfile','-ExecutionPolicy','Bypass','-File',$firewall,'-IncludePorts','-NoElevate') 90)
        $rules = @(Get-NetFirewallRule -ErrorAction Stop | Where-Object { $_.DisplayName -like 'MuMu-AdBlock:*' -and $_.Enabled -eq 'True' -and $_.Action -eq 'Block' })
        foreach ($name in @('MuMu-AdBlock: ad endpoint 34.36.47.246','MuMu-AdBlock: LAN port 7555','MuMu-AdBlock: LAN port 16384-16448','MuMu-AdBlock: LAN port 20511','MuMu-AdBlock: LAN port 23555-23633','MuMu-AdBlock: LAN port 24576-24640')) {
            if ($rules.DisplayName -notcontains $name) { throw "Firewall rule missing or not enabled: $name" }
        }
        $setting = Manager @('setting','--vmindex',"$VmIndex",'--key','root_permission') | ConvertFrom-Json
        if (-not $state) {
            $state = [pscustomobject]@{ manager=$ManagerPath; instance=$VmIndex; originalRoot=[string]$setting.root_permission; components=@(); created=(Get-Date -Format o) }
            Save-State $state
        }
        if ([string]$setting.root_permission -ne 'true') {
            Write-Host 'Enabling root for this instance through MuMu Manager. Root increases access inside Android.'
            [void](Manager @('setting','--vmindex',"$VmIndex",'--key','root_permission','--value','true'))
            $checkRoot = Manager @('setting','--vmindex',"$VmIndex",'--key','root_permission') | ConvertFrom-Json
            if ([string]$checkRoot.root_permission -ne 'true') { throw 'MuMu Manager did not enable root.' }
        }
        Ensure-Root
        $dump = Shell 'dumpsys package com.mumu.store'
        foreach ($class in Get-WidgetComponents) {
            if ($dump -notmatch [regex]::Escape($class.Substring('com.mumu.store'.Length))) { throw "Widget provider not found: $class. This build may differ; no substitute will be guessed." }
            if (-not (@($state.components | ForEach-Object { $_.class }) -contains $class)) {
                $state.components = @($state.components) + [pscustomobject]@{ class=$class; original=(Get-ComponentState $dump $class) }
            }
        }
        Save-State $state
        foreach ($class in Get-WidgetComponents) {
            $result = Root-Shell "pm disable --user 0 com.mumu.store/$class"
            Write-Host $result
            if ($result -notmatch 'new state: disabled') { throw "Could not disable $class" }
        }
        [void](Verify-Widgets 'disabled')
        Write-Host "`nSUCCESS: firewall protection verified and both MuMu promotional widgets disabled." -ForegroundColor Green
        Write-Host 'Check your home screen and game connection. Rerun after a MuMu update if ads return.'
    } else {
        Write-Host 'Removing this tool''s firewall rules...'
        Write-Host (Invoke-Native $ps @('-NoProfile','-ExecutionPolicy','Bypass','-File',$firewall,'-Remove','-NoElevate') 90)
        if (@(Get-NetFirewallRule -ErrorAction Stop | Where-Object { $_.DisplayName -like 'MuMu-AdBlock:*' -or $_.DisplayName -like 'Block MuMu Ads *' }).Count -ne 0) { throw 'Some tool firewall rules remain.' }
        if (-not $state) { Write-Host 'Firewall undone. No saved widget/root state for this instance; those settings were left unchanged.'; return }
        Ensure-Root
        foreach ($component in $state.components) {
            if ((Get-WidgetComponents) -notcontains $component.class) { throw 'Unexpected component in saved state; refusing to change it.' }
            $verb = switch ($component.original) { 'disabled' {'disable'} 'enabled' {'enable'} 'default' {'default-state'} default { throw 'Invalid saved component state.' } }
            Write-Host (Root-Shell "pm $verb --user 0 com.mumu.store/$($component.class)")
            $readback = Shell 'dumpsys package com.mumu.store'
            if ((Get-ComponentState $readback $component.class) -ne $component.original) { throw 'Component restore verification failed.' }
        }
        if ($state.originalRoot -notin @('true','false')) { throw 'Invalid saved root state.' }
        [void](Manager @('setting','--vmindex',"$VmIndex",'--key','root_permission','--value',$state.originalRoot))
        $restoredRoot = Manager @('setting','--vmindex',"$VmIndex",'--key','root_permission') | ConvertFrom-Json
        if ([string]$restoredRoot.root_permission -ne $state.originalRoot) { throw 'Root-setting restore failed.' }
        Remove-Item -LiteralPath $statePath
        Write-Host 'SUCCESS: saved widget/root settings restored and firewall rules removed. Root-setting changes may require a MuMu restart.' -ForegroundColor Green
    }
} catch {
    Write-Host "`nNOT COMPLETE: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Some earlier steps may already have applied. Saved state is kept so you can rerun or Undo.'
    $exitCode = 1
} finally {
    Write-Host "`nLog: $log"
    if ($transcribing) { Stop-Transcript | Out-Null }
    if (-not $NoPause) { [void](Read-Host 'Press Enter to close') }
}
exit $exitCode

<#
.SYNOPSIS
    Block MuMu Player's ad/promo traffic and (optionally) close its
    LAN-exposed ports, using Windows Firewall rules.

.DESCRIPTION
    MuMu Player (NetEase's Android emulator) pulls promotional content
    at runtime from remote endpoints - no update needed for ads to appear.
    This script adds outbound firewall rules blocking those endpoints,
    and can optionally block inbound access to MuMu's LAN-exposed ports
    (ADB 7555 and its per-instance service ports), which are bound to
    0.0.0.0 by default and reachable by any device on your network.

    Everything is done with standard Windows Firewall rules - fully
    reversible with -Remove, no system files touched.

    Firewall rules need admin rights. Run from a normal (non-admin)
    window, the script asks Windows for admin and finishes in a new
    admin window. The .cmd files next to this script do exactly that,
    so you can just double-click them.

.PARAMETER Remove
    Remove all rules previously created by this script.

.PARAMETER IncludePorts
    Also block INBOUND access to MuMu's LAN-exposed ports
    (7555 ADB + per-instance service ports) from other devices on your
    network. Localhost ADB keeps working.

.PARAMETER ExtraIp
    Additional IP(s) to block outbound, if MuMu starts using new ad
    endpoints. Separate several with commas:
    -ExtraIp 203.0.113.10,203.0.113.11

.PARAMETER KeepWindowOpen
    Wait for Enter before exiting, so a window opened by double-clicking
    doesn't close before you can read the result.

.PARAMETER NoElevate
    Don't ask Windows for admin rights; just print an error if this
    isn't already an admin session. For scripts and automation.

.EXAMPLE
    Double-click "Block MuMu Ads.cmd"
    Blocks the ad endpoints (same as running the script with no options).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\block_mumu_ads.ps1
    Blocks the ad endpoints.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\block_mumu_ads.ps1 -IncludePorts
    Blocks ad endpoints AND closes the LAN-exposed ports.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\block_mumu_ads.ps1 -Remove
    Removes every rule this script created.

.NOTES
    Requires Windows PowerShell 5.1+ and admin rights (asked for
    automatically unless -NoElevate is used).
    Works with MuMu Player 12 (nx_main / nx_device layout).
    MIT License - share freely.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Remove,
    [switch]$IncludePorts,
    [string[]]$ExtraIp = @(),
    [switch]$KeepWindowOpen,
    [switch]$NoElevate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Through `powershell -File` (and the admin relaunch) -ExtraIp arrives as one
# string like "1.2.3.4,5.6.7.8", so split it into separate IPs here.
$ExtraIp = @($ExtraIp | ForEach-Object { $_ -split '[,;\s]+' } | Where-Object { $_ })

# Known MuMu promo/ad endpoints.
# If ads return, check what MuMu processes talk to and add IPs via -ExtraIp.
$Script:AdEndpoints = @(
    '34.36.47.246'     # MuMu service backend
)

# These addresses were previously treated as ad-only, but Diablo Immortal also
# uses them during startup. Remove either rule name created by older versions.
$Script:DeprecatedEndpointRules = @(
    'MuMu-AdBlock: ad endpoint 48.216.202.246'
    'Block MuMu Ads 48.216.202.246'
    'MuMu-AdBlock: ad endpoint 34.117.122.6'
    'Block MuMu Ads 34.117.122.6'
)

# MuMu's LAN-exposed listener ports:
#   7555                     - ADB (unauthenticated, full shell access)
#   16384/16416/16448        - per-instance hypervisor service ports
#   20511                    - MuMuNxMain launcher service (HTTP API)
#   23555-23633, 24576-24640 - MuMuNxDevice per-instance HTTP APIs
$Script:ExposedPortRanges = @(
    '7555'
    '16384-16448'
    '20511'
    '23555-23633'
    '24576-24640'
)

$RulePrefixAds   = 'MuMu-AdBlock: ad endpoint'
$RulePrefixPorts = 'MuMu-AdBlock: LAN port'
$RulePrefixExtra = 'MuMu-AdBlock: extra endpoint'

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$id
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-NeedsAdmin {
    Write-Host ''
    Write-Host 'ERROR: This script must run as Administrator.' -ForegroundColor Red
    Write-Host 'Right-click PowerShell -> "Run as administrator", then re-run.' -ForegroundColor Yellow
}

function Start-Elevated {
    # Re-run this same script in a new admin window with the same options.
    # -KeepWindowOpen is always added so that window stays up until Enter.
    # Returns $false if Windows didn't start it (e.g. the prompt was cancelled).
    if (-not $PSCommandPath) { return $false }

    $exeName = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh.exe' } else { 'powershell.exe' }
    $exe = Join-Path $PSHOME $exeName

    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $PSCommandPath))
    if ($Remove)                      { $argList += '-Remove' }
    if ($IncludePorts)                { $argList += '-IncludePorts' }
    if ($ExtraIp.Count -gt 0)         { $argList += '-ExtraIp', ($ExtraIp -join ',') }
    if ($WhatIfPreference)            { $argList += '-WhatIf' }
    if ($ConfirmPreference -eq 'Low') { $argList += '-Confirm' }
    $argList += '-KeepWindowOpen'

    # -WhatIf/-Confirm were just passed on to the admin window; don't let them
    # also stop the relaunch itself (on PowerShell versions where they could).
    $WhatIfPreference = $false
    $ConfirmPreference = 'High'

    try {
        Start-Process -FilePath $exe -Verb RunAs -ArgumentList ($argList -join ' ') | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Get-OurRules {
    Get-NetFirewallRule -ErrorAction SilentlyContinue |
        Where-Object {
            $_.DisplayName -like 'MuMu-AdBlock:*' -or
            $_.DisplayName -like 'Block MuMu Ads *'
        }
}

function Remove-DeprecatedEndpointRules {
    foreach ($name in $Script:DeprecatedEndpointRules) {
        $rules = @(Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue)
        foreach ($rule in $rules) {
            Remove-NetFirewallRule -Name $rule.Name
            Write-Host "  removed deprecated rule: $($rule.DisplayName)" -ForegroundColor Yellow
        }
    }
}

function Remove-Rules {
    $rules = @(Get-OurRules)
    if ($rules.Count -eq 0) {
        Write-Host 'No MuMu-AdBlock rules found - nothing to remove.' -ForegroundColor Yellow
        return
    }
    foreach ($r in $rules) {
        Remove-NetFirewallRule -Name $r.Name
        Write-Host "  removed: $($r.DisplayName)" -ForegroundColor DarkGray
    }
    Write-Host ''
    Write-Host "Removed $($rules.Count) rule(s). MuMu is back to stock behavior." -ForegroundColor Green
}

function Add-OutboundBlock([string]$Ip, [string]$Prefix) {
    $name = "$Prefix $Ip"
    $existingRules = @(Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue)
    if ($Prefix -eq $RulePrefixAds) {
        $existingRules += @(Get-NetFirewallRule -DisplayName "Block MuMu Ads $Ip" -ErrorAction SilentlyContinue)
    }
    if ($existingRules.Count -gt 0) {
        Write-Host "  already blocked: $Ip" -ForegroundColor DarkGray
        return
    }
    New-NetFirewallRule -DisplayName $name -Direction Outbound -Action Block `
        -RemoteAddress $Ip -Profile Any -Enabled True | Out-Null
    Write-Host "  blocked outbound: $Ip" -ForegroundColor Green
}

function Add-InboundPortBlock([string]$PortRange) {
    $name = "$RulePrefixPorts $PortRange"
    if (Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue) {
        Write-Host "  already exists: $name" -ForegroundColor DarkGray
        return
    }
    # NOTE: blocks inbound from the LAN only; localhost (127.0.0.1) traffic is
    # unaffected, so `adb connect 127.0.0.1:7555` on this PC keeps working.
    New-NetFirewallRule -DisplayName $name -Direction Inbound -Action Block `
        -Protocol TCP -LocalPort $PortRange -RemoteAddress 'LocalSubnet' `
        -Profile Any -Enabled True | Out-Null
    Write-Host "  blocked inbound from LAN: TCP $PortRange" -ForegroundColor Green
}

function Test-TcpConnection([string]$Ip, [int]$Port, [int]$TimeoutMilliseconds) {
    $client = New-Object System.Net.Sockets.TcpClient
    $asyncResult = $null
    try {
        $asyncResult = $client.BeginConnect($Ip, $Port, $null, $null)
        if (-not $asyncResult.AsyncWaitHandle.WaitOne($TimeoutMilliseconds, $false)) {
            return $false
        }
        $client.EndConnect($asyncResult)
        return $client.Connected
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $asyncResult) {
            $asyncResult.AsyncWaitHandle.Close()
        }
        $client.Close()
    }
}

function Test-AdEndpointsReachable {
    Write-Host ''
    Write-Host 'Verifying blocks (each should say "blocked"):' -ForegroundColor Cyan
    foreach ($ip in $Script:AdEndpoints) {
        $ok = Test-TcpConnection $ip 443 3000
        $status = if ($ok) { 'REACHABLE (unexpected!)' } else { 'blocked' }
        $color  = if ($ok) { 'Red' } else { 'Green' }
        Write-Host ("  {0,-16} : {1}" -f $ip, $status) -ForegroundColor $color
    }
}

function Invoke-Block {
    Remove-DeprecatedEndpointRules

    Write-Host ''
    Write-Host '=== MuMu AdBlock ===' -ForegroundColor Cyan
    Write-Host ''

    Write-Host 'Blocking ad/promo endpoints (outbound):' -ForegroundColor Cyan
    foreach ($ip in $Script:AdEndpoints) { Add-OutboundBlock $ip $RulePrefixAds }

    foreach ($ip in $ExtraIp) {
        if ($ip -notmatch '^\d{1,3}(\.\d{1,3}){3}$') {
            Write-Host "  skipping invalid IP: $ip" -ForegroundColor Yellow
            continue
        }
        Add-OutboundBlock $ip $RulePrefixExtra
    }

    if ($IncludePorts) {
        Write-Host ''
        Write-Host 'Closing LAN-exposed ports (inbound, localhost unaffected):' -ForegroundColor Cyan
        foreach ($range in $Script:ExposedPortRanges) { Add-InboundPortBlock $range }
    }

    Test-AdEndpointsReachable

    Write-Host ''
    Write-Host 'Done.' -ForegroundColor Green
    Write-Host 'Existing connections may take ~1-2 minutes to time out; restarting'
    Write-Host 'MuMu flushes them immediately.'
    Write-Host 'To undo everything: double-click "Undo MuMu AdBlock.cmd"'
    Write-Host '                or: .\block_mumu_ads.ps1 -Remove'
}

$exitCode = 0
$handedOffToAdminWindow = $false
try {
    if (-not (Test-IsAdmin)) {
        if ($NoElevate) {
            Write-NeedsAdmin
            $exitCode = 1
        }
        else {
            Write-Host 'Admin rights needed - asking Windows (click Yes if it asks)...' -ForegroundColor Cyan
            if (Start-Elevated) {
                $handedOffToAdminWindow = $true
            }
            else {
                Write-Host ''
                Write-Host "Couldn't get admin rights (the prompt was cancelled or blocked), so nothing was changed." -ForegroundColor Red
                Write-Host 'Run it again and click Yes, or right-click PowerShell -> "Run as administrator".' -ForegroundColor Yellow
                $exitCode = 1
            }
        }
    }
    elseif ($Remove) {
        Remove-Rules
    }
    else {
        Invoke-Block
    }
}
catch {
    Write-Host ''
    Write-Host ($_ | Out-String) -ForegroundColor Red
    $exitCode = 1
}
finally {
    # Double-clicked windows close as soon as the script ends; wait so the
    # result can be read. Not needed when the admin window took over.
    if ($KeepWindowOpen -and -not $handedOffToAdminWindow) {
        Write-Host ''
        try { [void](Read-Host 'Press Enter to close this window') } catch { }
    }
}
exit $exitCode

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

.PARAMETER Remove
    Remove all rules previously created by this script.

.PARAMETER IncludePorts
    Also block INBOUND access to MuMu's LAN-exposed ports
    (7555 ADB + per-instance service ports) from other devices on your
    network. Localhost ADB keeps working.

.PARAMETER ExtraIp
    Additional IP(s) to block outbound, if MuMu starts using new ad
    endpoints. Can be specified multiple times.

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
    Requires Windows PowerShell 5.1+ and an elevated (admin) session.
    Works with MuMu Player 12 (nx_main / nx_device layout).
    MIT License - share freely.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Remove,
    [switch]$IncludePorts,
    [string[]]$ExtraIp = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Known MuMu promo/ad endpoints (Google Cloud load balancers fronting
# NetEase's MuMu services - shared infrastructure, same for all users).
# If ads return, check what MuMu processes talk to and add IPs via -ExtraIp.
$Script:AdEndpoints = @(
    '48.216.202.246'   # primary promo/recommendation feed
    '34.36.47.246'     # MuMu service backend
    '34.117.122.6'     # MuMu service backend
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

function Assert-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$id
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host ''
        Write-Host 'ERROR: This script must run as Administrator.' -ForegroundColor Red
        Write-Host 'Right-click PowerShell -> "Run as administrator", then re-run.' -ForegroundColor Yellow
        exit 1
    }
}

function Get-OurRules {
    Get-NetFirewallRule -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like 'MuMu-AdBlock:*' }
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
    if (Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue) {
        Write-Host "  already exists: $name" -ForegroundColor DarkGray
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

function Test-AdEndpointsReachable {
    Write-Host ''
    Write-Host 'Verifying blocks (each should say "blocked"):' -ForegroundColor Cyan
    foreach ($ip in $Script:AdEndpoints) {
        $ok = Test-Connection -TargetName $ip -TcpPort 443 -TimeoutSeconds 3 -Quiet -ErrorAction SilentlyContinue
        $status = if ($ok) { 'REACHABLE (unexpected!)' } else { 'blocked' }
        $color  = if ($ok) { 'Red' } else { 'Green' }
        Write-Host ("  {0,-16} : {1}" -f $ip, $status) -ForegroundColor $color
    }
}

Assert-Admin

if ($Remove) {
    Remove-Rules
    exit 0
}

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
Write-Host 'To undo everything:  .\block_mumu_ads.ps1 -Remove'

    '24576-24640'
)

$RulePrefixAds   = 'MuMu-AdBlock: ad endpoint'
$RulePrefixPorts = 'MuMu-AdBlock: LAN port'
$RulePrefixExtra = 'MuMu-AdBlock: extra endpoint'

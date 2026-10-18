$ErrorActionPreference = 'Stop'
$module = Join-Path $PSScriptRoot '..\src\MuMu.Core.psm1'
if (-not (Test-Path $module)) { throw 'Missing combined-tool core module' }
Import-Module $module -Force
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$dump = "User 0: installed=true`n  enabledComponents:`n    example.Other`n  disabledComponents:`n    com.mumu.store.widget.appWidgetProvider.AdBannerWidgetProvider`n`nQueries:`n  com.mumu.store.widget.appWidgetProvider.DailyDiscoveryWidgetProvider"
Assert ((Get-ComponentState $dump 'com.mumu.store.widget.appWidgetProvider.AdBannerWidgetProvider') -eq 'disabled') 'Must find disabled provider'
Assert ((Get-ComponentState $dump 'com.mumu.store.widget.appWidgetProvider.DailyDiscoveryWidgetProvider') -eq 'default') 'A name elsewhere must not count as disabled'
Assert ((Get-ComponentState $dump 'example.Other') -eq 'enabled') 'Must preserve explicitly enabled state'
Assert ((ConvertTo-NativeArgument 'path with spaces') -eq '"path with spaces"') 'Quote spaces'
Assert ((ConvertTo-NativeArgument 'shell su -c "pm disable x/y"') -eq '"shell su -c \"pm disable x/y\""') 'Preserve nested shell quotes'
Assert ((Get-WidgetComponents).Count -eq 2) 'Only two targeted providers'
Assert (-not ((Get-WidgetComponents) -match 'Smartspace|login')) 'Do not alter unrelated components'
Write-Host 'PASS: component-state parsing, native quoting, targeted providers'

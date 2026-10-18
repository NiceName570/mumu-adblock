Set-StrictMode -Version Latest
function Get-WidgetComponents {
    @('com.mumu.store.widget.appWidgetProvider.AdBannerWidgetProvider',
      'com.mumu.store.widget.appWidgetProvider.DailyDiscoveryWidgetProvider')
}
function Get-ComponentState([string]$Dump, [string]$Class) {
    # Only inspect the user-0 overrides, not resolver tables or other users.
    $user = [regex]::Match($Dump, '(?ms)^\s*User 0:.*?(?=^\s*User \d+:|^Queries:|\z)').Value
    foreach ($state in @('disabled', 'enabled')) {
        $section = [regex]::Match($user, '(?ms)^\s*' + $state + 'Components:\s*\r?\n((?:[ \t]+[^\r\n]+\r?\n?)*)').Groups[1].Value
        if (($section -split '\r?\n' | ForEach-Object { $_.Trim() }) -contains $Class) { return $state }
    }
    return 'default'
}
function ConvertTo-NativeArgument([string]$Value) {
    # Windows CommandLineToArgvW rules; preserve quotes inside --cmd.
    if ($Value -notmatch '[\s"]' -and $Value.Length -gt 0) { return $Value }
    return '"' + ([regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1')) + '"'
}
function Invoke-Native([string]$File, [string[]]$Arguments, [int]$TimeoutSeconds = 45) {
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $File
    $info.Arguments = ($Arguments | ForEach-Object { ConvertTo-NativeArgument $_ }) -join ' '
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill()
            throw "Command timed out: $File"
        }
        $text = $stdout.Result + $stderr.Result
        if ($process.ExitCode -ne 0) { throw "Command failed ($($process.ExitCode)): $text" }
        return $text.Trim()
    } finally { $process.Dispose() }
}
function Find-MuMuManager {
    $candidates = New-Object 'System.Collections.Generic.List[string]'
    Get-CimInstance Win32_Process -Filter "Name='MuMuNxMain.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.ExecutablePath) { $candidates.Add((Join-Path (Split-Path $_.ExecutablePath) 'MuMuManager.exe')) }
    }
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if ($base) {
            $candidates.Add((Join-Path $base 'Netease\MuMuPlayer\nx_main\MuMuManager.exe'))
            $candidates.Add((Join-Path $base 'Netease\MuMu Player 12\shell\MuMuManager.exe'))
        }
    }
    foreach ($key in @('HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*', 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*')) {
        Get-ItemProperty $key -ErrorAction SilentlyContinue | Where-Object { $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -match 'MuMu' } | ForEach-Object {
            if ($_.PSObject.Properties['InstallLocation'] -and $_.InstallLocation) {
                foreach ($part in @('nx_main\MuMuManager.exe', 'shell\MuMuManager.exe', 'MuMuManager.exe')) {
                    $candidates.Add((Join-Path $_.InstallLocation $part))
                }
            }
        }
    }
    return @($candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -Unique)
}
Export-ModuleMember -Function Get-WidgetComponents, Get-ComponentState, ConvertTo-NativeArgument, Invoke-Native, Find-MuMuManager

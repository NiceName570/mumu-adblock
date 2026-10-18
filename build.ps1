$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = $PSScriptRoot
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path $csc)) { throw 'The Windows .NET Framework C# compiler was not found.' }
foreach ($file in @('src\MuMu-AdBlock.ps1','src\MuMu.Core.psm1','block_mumu_ads.ps1')) {
    $errors = $null; $tokens = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file), [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw ($errors | Out-String) }
}
& (Join-Path $root 'tests\test-core.ps1')
$out = Join-Path $root 'mumu_adblock.exe'
& $csc /nologo /target:exe /optimize+ /reference:System.Windows.Forms.dll "/out:$out" "/resource:$(Join-Path $root 'src\MuMu-AdBlock.ps1'),MuMu-AdBlock.ps1" "/resource:$(Join-Path $root 'src\MuMu.Core.psm1'),MuMu.Core.psm1" "/resource:$(Join-Path $root 'block_mumu_ads.ps1'),block_mumu_ads.ps1" (Join-Path $root 'src\Launcher.cs')
if ($LASTEXITCODE -ne 0) { throw 'Compilation failed.' }
& $out --self-test
if ($LASTEXITCODE -ne 0) { throw 'Embedded-script test failed.' }
$zip = Join-Path $root 'mumu_adblock.zip'
Compress-Archive -LiteralPath $out,(Join-Path $root 'README.md'),(Join-Path $root 'LICENSE') -DestinationPath $zip -Force
Get-FileHash -LiteralPath $out,$zip -Algorithm SHA256 | Format-Table -AutoSize

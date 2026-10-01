@echo off
rem Double-click to remove every firewall rule MuMu AdBlock made.
rem Windows asks for admin rights - click Yes.
if not exist "%~dp0block_mumu_ads.ps1" (
    echo Can't find block_mumu_ads.ps1 next to this file.
    echo Extract the whole zip first, then double-click this file again.
    echo.
    pause
    exit /b 1
)
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0block_mumu_ads.ps1" -Remove -KeepWindowOpen

# MuMu AdBlock

![MuMu AdBlock banner](banner.png)

Removed MuMu Player startup ads and remove the identified home-screen promotional widgets made it double click so its easy for everyone.
## Quick start

1. Download [mumu_adblock.exe (v2.0.0)](https://github.com/NiceName570/mumu-adblock/releases/download/v2.0.0/mumu_adblock.exe) or the [ZIP](https://github.com/NiceName570/mumu-adblock/releases/download/v2.0.0/mumu_adblock.zip) and extract it.
2. Double-click **mumu_adblock.exe**. Approve the Windows administrator prompt only if you trust this download.
3. Choose **Apply**, then select your MuMu instance if asked. Read the root warning and approve any required start/restart when ready; save your game first.
4. Choose **Check**, inspect the MuMu home screen, and test your game's login and connection.

**Unsigned executable:** Windows SmartScreen or antivirus may warn about this community-built tool. Download only from this repository's [release page](https://github.com/NiceName570/mumu-adblock/releases/tag/v2.0.0), review the source, or build it yourself if unsure. Do not disable antivirus or ignore a detection just to run it.

Requires Windows 10/11, Windows PowerShell 5.1+, administrator access, and an installed MuMu Player with `MuMuManager.exe`. Other MuMu versions may differ from the investigated build.

## What changes

- **Network:** runs the existing `block_mumu_ads.ps1 -IncludePorts` behavior: blocks outbound traffic to startup-ad endpoint `34.36.47.246` and inbound TCP connections from your LAN to ports `7555`, `16384–16448`, `20511`, `23555–23633`, and `24576–24640`. These are **not outbound port blocks**. Localhost access on your own PC is unaffected.
- **Game compatibility:** leaves `48.216.202.246` and `34.117.122.6` unblocked and removes older tool rules for them, because Diablo Immortal also uses these addresses. Still test game connectivity after applying.
- **Widgets:** disables only these two Android components, not the store or launcher as a whole:
  - `com.mumu.store/com.mumu.store.widget.appWidgetProvider.AdBannerWidgetProvider`
  - `com.mumu.store/com.mumu.store.widget.appWidgetProvider.DailyDiscoveryWidgetProvider`
- **Root:** discovers the installed manager and lets you choose an instance. If needed, it enables that instance's `root_permission` setting through the manager. Root may require a restart; starting or restarting MuMu requires confirmation.

**Root is a security tradeoff:** it allows privileged changes inside Android and may affect game compatibility or security checks. LAN filtering does not make root harmless. Use **Undo** to restore the saved root setting when you no longer want these changes.

The single-file EXE embeds the editable PowerShell scripts. It uses MuMu's own manager for commands (`adb --vmindex N --cmd 'shell su -c ...'`) and checks the package's `disabledComponents` list rather than assuming a successful command means the widgets are disabled.

## Undo and local records

Choose **Undo** in the EXE to restore the saved component states and root setting and remove existing tool-created firewall rules. Keep `%LOCALAPPDATA%\MuMu-AdBlock` until you have undone the changes: it holds local state and logs needed for restoration. Treat those records as private when sharing diagnostics.

The tool does **not** clear launcher/game data or delete apps. It does not unlock paid features or promise to remove every ad. IP-based blocking can stop working if the service moves. A screenshot confirmed the targeted card disappeared in the investigated instance; **persistence after restart has not yet been tested**. See [the evidence summary](ADB-DISABLE-SUMMARY.md).

## Legacy firewall-only shortcuts

These still work from the source checkout/extracted source, but **do not change widgets or root**:

| File | Action |
|---|---|
| `Block MuMu Ads.cmd` | Block the known startup-ad endpoint |
| `Block MuMu Ads + Close LAN Ports.cmd` | Also block inbound LAN access to the listed ports |
| `Undo MuMu AdBlock.cmd` | Remove tool firewall rules only; use EXE Undo to restore widget/root state |

## Build from source

Edit the PowerShell sources, then run in the repository folder:

```powershell
powershell -File build.ps1
```

See [PROJECT-LOG](docs/PROJECT-LOG.md) for the design rationale and evidence limits.

## License

[MIT](LICENSE).

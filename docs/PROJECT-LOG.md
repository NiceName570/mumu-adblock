# Project log

## User idea and chosen design

The user wanted to combine the existing **startup-ad network blocker and LAN protection** with **MuMu-manager-assisted root and targeted promotional-widget removal** in one double-click tool. It should remain easy to edit, not require the user to assemble ADB commands, and offer a clear way back.

The chosen design is a single `mumu_adblock.exe` with embedded PowerShell scripts and an **Apply / Undo / Check** menu. The PowerShell sources remain editable, with `powershell -File build.ps1` rebuilding the executable. MuMu's installed `MuMuManager.exe` handles instance discovery/selection, root configuration, and ADB commands rather than relying on a guessed standalone ADB port.

## Why combine two layers?

The existing `block_mumu_ads.ps1 -IncludePorts` handles Windows networking: outbound blocking of startup-ad endpoint `34.36.47.246` plus inbound TCP filtering from the LAN. The port rules are not outbound blocks, and localhost is unaffected. Diablo Immortal's shared endpoints `48.216.202.246` and `34.117.122.6` stay unblocked; deprecated tool rules for them are removed.

Network blocking alone is not the same as removing an installed launcher widget. `dumpsys appwidget` and the Lawnchair favorites database identified the actual promotional providers in `com.mumu.store`:

- `com.mumu.store/com.mumu.store.widget.appWidgetProvider.AdBannerWidgetProvider`
- `com.mumu.store/com.mumu.store.widget.appWidgetProvider.DailyDiscoveryWidgetProvider`

Only these two components are targeted. Disabling an entire store/launcher, clearing launcher data, or guessing that Smartspace owns the card would be broader than the evidence supports.

## Reversibility and safety

- Save the original component states and instance root setting under `%LOCALAPPDATA%\MuMu-AdBlock`, alongside local logs.
- Enable `root_permission` through the manager only if needed; prompt before an instance start/restart. Root may require a restart and expands privileged access inside Android.
- Execute privileged commands through `adb --vmindex N --cmd 'shell su -c ...'` and verify the target package's `disabledComponents`.
- Undo restores the saved component/root states and removes existing tool firewall rules. Do not clear app data or delete apps.
- Keep the legacy `.cmd` launchers available as **firewall-only** options.
- Document that the community executable is unsigned; do not tell users to disable antivirus. Ask users to check game connectivity after applying.

## Evidence and open checks

Root access was demonstrated by `shell su -c id` returning uid 0. A fresh screenshot confirmed the promotional card disappeared after the targeted components were disabled. **Persistence after restarting MuMu is not yet tested.** This manual evidence must not be presented as a completed end-to-end EXE test or proof that every ad is gone.

Earlier notes were corrected: Smartspace was not the identified card owner; a bundled notification receiver is not proof of malware; failed installer-inspection tools did not prove the installer was packed/obfuscated. See [the investigation summary](../ADB-DISABLE-SUMMARY.md).

## Build and execution results

- Built the single-file EXE with the installed Windows .NET Framework C# compiler. Core tests passed for component-state parsing, nested native-command quoting, and the two-provider allowlist. The EXE's self-test parsed all three embedded scripts successfully.
- Executed the EXE's Apply against MuMu instance 1. Its log recorded the startup-ad endpoint block and five inbound LAN-port rules, followed by both providers reporting disabled.
- Executed the EXE's Check afterward: root shell returned uid 0; both providers were read back as disabled; all six expected firewall rules were enabled with Block action. The user subsequently confirmed it works and approved publishing.
- The live instance already had root enabled, so the root-off/start/restart path was not exercised end to end. The Undo test permission prompt timed out and Undo was not executed. Neither is represented as a verified live test.
- No emulator restart or game-connectivity test was performed by the assistant during this packaging run.

Distribution: [v2.0.0 release](https://github.com/NiceName570/mumu-adblock/releases/tag/v2.0.0), with EXE and ZIP downloads. Source remains in `src/`, with `build.ps1` and `tests/test-core.ps1`.

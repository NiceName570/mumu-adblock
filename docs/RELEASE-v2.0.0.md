# MuMu AdBlock 2.0 — double-click protection

Download **mumu_adblock.exe**, double-click, accept the administrator prompt, then choose **Apply**. The ZIP contains the same EXE plus README and license; no separate ADB installation is required.

- Combines the startup-ad endpoint block, inbound LAN-port protection, and targeted removal of MuMu Store's two promotional widgets.
- Finds MuMu Manager, lets you select an instance, and enables root if necessary. Asks before starting/restarting the emulator.
- Includes Apply / Undo / Check, local logs, and saved component/root settings.
- Preserves Diablo Immortal's shared-address exceptions. Does not delete apps, reset launcher data, or change account/payment state.
- Corrects the earlier Smartspace attribution; the confirmed providers belong to MuMu Store.

The EXE is unsigned. Review the source or build it yourself if unsure; do not disable antivirus to run it. Root increases privileged access inside Android and may affect game compatibility.

Validation: source tests and embedded-script parsing passed. EXE Apply and Check were exercised against the running instance, verifying both disabled widgets and all six firewall rules; the user confirmed it works. Undo and the root-off/restart flow were not live-tested. Restart persistence and game connectivity were not independently tested. Full details are in docs/PROJECT-LOG.md.

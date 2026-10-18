# MuMu promotional-widget investigation

## Confirmed evidence

The investigated MuMu home screen uses Lawnchair (`app.lawnchair`). The promotional card's actual providers were identified by **`dumpsys appwidget` and the launcher's favorites database**, not inferred from bundled component names:

- `com.mumu.store/com.mumu.store.widget.appWidgetProvider.AdBannerWidgetProvider`
- `com.mumu.store/com.mumu.store.widget.appWidgetProvider.DailyDiscoveryWidgetProvider`

Root was confirmed by **`shell su -c id` returning uid 0**. An ordinary ADB shell can still be uid 2000; this is not evidence that `su` is unavailable. The earlier description of root as verified through `adb root` was inaccurate.

Disabling the targeted providers with root removed the visible promotional card, confirmed by a fresh screenshot. Package `disabledComponents` is the state to inspect when verifying component changes. **Persistence after a MuMu restart has not yet been tested.** This result is not a claim that all advertisements, account prompts, or paid-feature restrictions were removed.

## Corrections to earlier notes

- Lawnchair's `SmartspaceAppWidgetProvider` was **not** the identified owner of the “Games for you” card. Do not disable it as a substitute for the two store providers above.
- A bundled `com.mumu.core.notification.MuMuNotificationReceiver` is **not proof of malware**. Its presence alone does not establish what it does or justify disabling it.
- The inspection tools failed to establish the installer format. The old claim that `MuMu_6.0.2_WmTijNC.exe` was proven packed/obfuscated was unsupported; no such conclusion follows from failed tooling.
- There is no need to delete system APKs or clear launcher data to target these widgets. This investigation does not establish a blanket malware verdict for MuMu.

## Combined tool behavior

The v2.0.0 tool combines targeted widget control with the existing startup-network and LAN firewall blocker:

1. Discover the installed `MuMuManager.exe` and choose the intended instance.
2. Save the component states and instance root setting locally under `%LOCALAPPDATA%\MuMu-AdBlock` before changing them.
3. If required, set `root_permission` to true through the manager. Ask before starting or restarting the instance; root changes may need a restart.
4. Run privileged Android commands through the manager's `adb --vmindex N --cmd 'shell su -c ...'` interface. Disable **only** the two providers above and verify `disabledComponents`.
5. Apply the existing `block_mumu_ads.ps1 -IncludePorts` firewall behavior. Block outbound endpoint `34.36.47.246` and inbound LAN TCP ports; do not block outbound ports. Localhost remains unaffected.
6. Keep Diablo Immortal addresses `48.216.202.246` and `34.117.122.6` unblocked, removing deprecated tool rules for them.

**Undo** restores saved component/root states and removes existing tool firewall rules. It does not clear app data. The legacy `.cmd` files remain firewall-only and cannot restore Android component/root state.

Enabling root expands privileged access inside Android and can affect games' security or compatibility checks. Save active work before approving a restart, inspect the home screen after applying, and test game login/connectivity. The combined tool's build/release validation must be reported separately; the manual widget-removal evidence above is not an end-to-end EXE test.

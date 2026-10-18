# ADB / Root disable of baked-in MuMu launcher ads

What was done (verified with ADB to 127.0.0.1:7555, root via `adb root`):

1. Located the home launcher inside MuMu: `app.lawnchair` v12.1.0.37 at `/system/priv-app/app.lawnchair_overseas/app.lawnchair_overseas.apk`
2. Confirmed the "Games for you" recommendation box is the `SmartspaceAppWidgetProvider` baked into Lawnchair
3. Confirmed MuMu's notification/ad core is baked in as component `com.mumu.core.notification.MuMuNotificationReceiver`
4. `/system` is physically read-only (block device `sda6` ro), so the APK cannot be deleted — only components can be disabled via `pm disable`
5. Disabled both components with root ADB:
   - `pm disable --user 0 app.lawnchair/com.mumu.core.notification.MuMuNotificationReceiver`
   - `pm disable --user 0 app.lawnchair/.smartspace.SmartspaceAppWidgetProvider`
6. Both returned `new state: disabled`
7. The binary installer (`MuMu_6.0.2_WmTijNC.exe`) was packed/obfuscated — no readable source to inspect
8. User's LAN port block handles the network layer; this handles the baked-in launcher layer

No files deleted. No payment tool used. No separate "virus" app exists — the upsell was just the launcher widget.

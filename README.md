# MuMu AdBlock

![Banner](banner.png)

**What it does:** Stops MuMu Player launcher ads & promo endpoints (and optionally closes exposed LAN ports) using only Windows Firewall rules — no drivers, no installs.

**How to use:**
1. Download / clone this repo. 2. Double-click `Block MuMu Ads.cmd` → click **Yes** on admin prompt. 3. Restart MuMu. Ads blocked. 4. To also close LAN ports: use `Block MuMu Ads + Close LAN Ports.cmd`. 5. Undo anytime: `Undo MuMu AdBlock.cmd`.

Stop MuMu Player's launcher ads & promos — and (optionally) close the ports
it exposes to your LAN — using nothing but Windows Firewall rules.

## Quick start (no typing)

1. Click the green **Code** button → **Download ZIP**, then extract it
   (right-click the zip → **Extract All**).
2. Double-click **`Block MuMu Ads.cmd`**.
3. Windows asks for admin rights — click **Yes**.
4. Read the result, press **Enter** to close the window, then restart MuMu.

| Double-click | What it does |
|---|---|
| `Block MuMu Ads.cmd` | Blocks MuMu's ad endpoints |
| `Block MuMu Ads + Close LAN Ports.cmd` | Same, plus closes the LAN-exposed ports (see below) |
| `Undo MuMu AdBlock.cmd` | Removes every rule this tool made |

If Windows warns that the file came from the internet, choose **Run**
(or **More info → Run anyway**). To skip that warning, right-click the zip →
**Properties** → tick **Unblock** → **OK** before extracting.

## The problem

MuMu Player (NetEase's Android emulator) fetches promotional content **at
runtime** from remote endpoints. That's why ads can suddenly appear even if
you never updated: no update is needed, the launcher just phones home.

On top of that, MuMu binds several services to `0.0.0.0`, meaning they're
reachable by **any device on your local network**:

| Port(s) | What it is | Risk |
|---|---|---|
| `7555` | ADB — **no auth**, full shell into the emulator | 🔴 High |
| `16384/16416/16448` | Per-instance hypervisor services | 🟠 |
| `20511` | `MuMuNxMain` launcher HTTP API | 🟠 |
| `23555–23633`, `24576–24640` | `MuMuNxDevice` per-instance HTTP APIs | 🟠 |

## The fix

One PowerShell script. No installs, no drivers, no system files touched —
just firewall rules you can remove any time.

### 1. Block the ads

Double-click `Block MuMu Ads.cmd`, or from PowerShell in this folder:

```powershell
powershell -ExecutionPolicy Bypass -File .\block_mumu_ads.ps1
```

If PowerShell isn't running as Administrator, the script asks Windows for
admin rights and finishes in a new window.

This blocks outbound traffic to MuMu's known promo endpoints:

- `34.36.47.246`

`48.216.202.246` and `34.117.122.6` are deliberately not blocked. They were
included in the first release, but Diablo Immortal also uses both addresses
while connecting. Rerunning the current script automatically removes those
older rules while keeping the confirmed MuMu ad block.

Restart MuMu afterwards (existing connections take a minute to time out;
a restart flushes them instantly). Ads gone.

### 2. (Optional) Close the LAN-exposed ports

Double-click `Block MuMu Ads + Close LAN Ports.cmd`, or:

```powershell
powershell -ExecutionPolicy Bypass -File .\block_mumu_ads.ps1 -IncludePorts
```

Blocks **inbound from your LAN** to the ports in the table above.
Localhost is unaffected — `adb connect 127.0.0.1:7555` on your own PC
keeps working, so scrcpy/ADB tooling won't break.

### Undo everything

Double-click `Undo MuMu AdBlock.cmd`, or:

```powershell
.\block_mumu_ads.ps1 -Remove
```

Every rule the script created is named `MuMu-AdBlock: ...` and is removed
cleanly.

### New ad endpoints?

If NetEase rotates infrastructure, find what MuMu is talking to:

```powershell
$pids = (Get-Process | Where-Object ProcessName -match 'mumu|nemu').Id
Get-NetTCPConnection -State Established |
  Where-Object OwningProcess -in $pids |
  Group-Object RemoteAddress | Sort-Object Count -Descending
```

(Google-owned ranges like `142.250.x.x` / `172.217.x.x` are Play Services —
leave those. Anything else with lots of persistent connections is suspect.)
Then block it:

```powershell
.\block_mumu_ads.ps1 -ExtraIp 203.0.113.10
```

Several at once: `-ExtraIp 203.0.113.10,203.0.113.11`

## Requirements

- Windows 10/11, PowerShell 5.1+ (preinstalled)
- Administrator rights (firewall rules require elevation) — the script asks
  Windows for them itself, just click **Yes**

## Notes & limitations

- Verified against **MuMu Player 12**. Older/other versions may use
  different endpoints — use `-ExtraIp` for those.
- The script blocks **IPs**, not domains: if NetEase moves their ad service
  to new IPs, ads may return until you block the new ones.
- Does **not** touch anything inside the emulator itself. Because NetEase can
  reuse infrastructure between MuMu and games, test game connectivity after
  adding any address with `-ExtraIp`.
- Some launcher content is cached on disk; if a promo banner lingers after
  blocking, restart MuMu or clear the launcher app data.

## Contributing

Found a new ad endpoint or a better detection method? PRs welcome — keep
the rule prefix (`MuMu-AdBlock:`) so `-Remove` keeps working.

## License

MIT — see [LICENSE](LICENSE).

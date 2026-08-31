# MuMu AdBlock

Stop MuMu Player's launcher ads & promos — and (optionally) close the ports
it exposes to your LAN — using nothing but Windows Firewall rules.

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

Open **PowerShell as Administrator**, then:

```powershell
powershell -ExecutionPolicy Bypass -File .\block_mumu_ads.ps1
```

This blocks outbound traffic to MuMu's known promo endpoints:

- `48.216.202.246` (primary promo/recommendation feed)
- `34.36.47.246`
- `34.117.122.6`

Restart MuMu afterwards (existing connections take a minute to time out;
a restart flushes them instantly). Ads gone.

### 2. (Optional) Close the LAN-exposed ports

```powershell
powershell -ExecutionPolicy Bypass -File .\block_mumu_ads.ps1 -IncludePorts
```

Blocks **inbound from your LAN** to the ports in the table above.
Localhost is unaffected — `adb connect 127.0.0.1:7555` on your own PC
keeps working, so scrcpy/ADB tooling won't break.

### Undo everything

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

## Requirements

- Windows 10/11, PowerShell 5.1+ (preinstalled)
- Administrator rights (firewall rules require elevation)

## Notes & limitations

- Verified against **MuMu Player 12**. Older/other versions may use
  different endpoints — use `-ExtraIp` for those.
- The script blocks **IPs**, not domains: if NetEase moves their ad service
  to new IPs, ads may return until you block the new ones.
- Does **not** touch anything inside the emulator itself — games and apps
  in the instance keep working normally, including Google Play.
- Some launcher content is cached on disk; if a promo banner lingers after
  blocking, restart MuMu or clear the launcher app data.

## Contributing

Found a new ad endpoint or a better detection method? PRs welcome — keep
the rule prefix (`MuMu-AdBlock:`) so `-Remove` keeps working.

## License

MIT — see [LICENSE](LICENSE).

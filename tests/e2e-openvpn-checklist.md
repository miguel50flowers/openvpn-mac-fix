# E2E checklist — OpenVPN connect/disconnect auto-fix

End-to-end verification of the core behavior: when a VPN goes
**connected → disconnected**, the helper detects the transition and runs the
network-recovery fix. This path needs a real VPN, the root helper, and a logged-in GUI
session, so it is run by hand. Use `tests/e2e-watch.sh` for an objective log signal.

## Prerequisites

1. Build and install the app (which installs the privileged helper):
   - `make app`, then open `build/DerivedData/Build/Products/Release/VPN Fix.app`.
   - Approve the helper installation prompt; enable monitoring in the app.
   - Confirm the helper is loaded: `make status` (look for `com.miguel50flowers.VPNFix.helper`).
2. Have an OpenVPN client/profile ready to connect and disconnect.
3. In a separate terminal, start the watcher: `make e2e-watch` (or `tests/e2e-watch.sh`).

## Steps

| # | Action | Expected result |
|---|--------|-----------------|
| 1 | Connect OpenVPN | App menu bar shows the VPN as active. Log shows a baseline/`State …→connected` line. No fix runs. |
| 2 | Confirm routing | `netstat -rn` shows `0/1` and `128.0/1` via a `utun` interface. |
| 3 | Disconnect OpenVPN | Within ~10s the log shows `[AutoFix] VPN disconnection confirmed (no VPN tunnel process running), running fix...` followed by `[FIX] … Network recovery completed`. |
| 4 | Confirm recovery | DNS resolves again (`dscacheutil -q host -a name apple.com` or open a website); `netstat -rn` shows a `default` route via `en0`/Wi-Fi, no stale `utun` `0/1`/`128.0/1`. |
| 5 | Menu bar updates | App shows the VPN as disconnected / all-clear. |
| 6 | Cooldown | Immediately reconnect and disconnect again within 30s → log shows `no fix (cooldown active)`; the fix does **not** run a second time. |
| 7 | No fix while connecting | During step 1 (connection coming up) the log must **not** run a fix; only a `connected` state update. |

## Pass criteria

- Step 3 fires the auto-fix on a real disconnect (this is the regression that was broken).
- `tests/e2e-watch.sh --wait 60` exits `PASS` when you disconnect within the window.
- Steps 6–7 confirm the cooldown and the "don't fix while a tunnel is up" guards still hold.

## If it fails

- No fix line at all → confirm monitoring is enabled and the helper is loaded (`make status`),
  then tail `make logs`. Check the disconnect was a true connected→disconnected transition
  (a flapping reconnect within the cooldown is intentionally skipped).
- Fix runs while still connected → check `netstat -rn`; the tunnel routes should be gone.

---

# E2E checklist — network-health detection + SAFE "Fix Everything"

This is the scenario that motivated the Phase 5 work: a disconnect (often FortiClient +
OpenVPN) left the internet broken while the app reported **0 issues**, and pressing
"Fix Everything" made it **worse** and left no internet. These steps verify the two fixes:
broken connectivity is now **detected**, and the repair is **safe** — it never breaks a working
network and never leaves you offline.

## A. Detection — a broken network is surfaced (no auto-fix)

| # | Action | Expected result |
|---|--------|-----------------|
| 1 | With no VPN connected, simulate a broken default route: `sudo route -n delete default` (note your gateway first with `route -n get default`). | Within one scan interval the app shows a **"Network"** entry with a critical issue (`No default route …`). The menu-bar badge issue count increases. A notification appears. **No automatic fix runs** (by design — detect + notify only). |
| 2 | Simulate DNS failure instead: point DNS at a dead resolver, or disconnect upstream so lookups fail. | App shows a **"Network"** entry with `DNS is not resolving …`. |
| 3 | Restore the gateway (`sudo route -n add default <gw>`). | On the next scan the "Network" entry clears. No fix was ever auto-run. |

## B. Safe repair — "Fix Everything" never makes it worse

| # | Action | Expected result |
|---|--------|-----------------|
| 4 | With a **healthy** network, press "Fix Everything". | Log: `[SafeFix] already healthy — no changes made`. Connectivity is untouched (the old code would churn interfaces/IPv6/pf here). |
| 5 | Break the network (delete the default route as in step 1), then press "Fix Everything" / the Network entry's Fix. | Log shows `[SafeFix] pre-probe … healthy=false`, a `plan: …` line, then steps run **sequentially** (`[SafeFix] step: …`). The run **stops as soon as connectivity returns** (later steps are skipped). Final line reports `Connectivity restored (…)`. |
| 6 | Confirm you are never left offline. | At every point during step 5, and especially at the end, `route -n get default` shows a gateway via `en*`/Wi-Fi and `networksetup -getinfo "<your service>"` shows it enabled. IPv6 is **automatic**, never off (`networksetup -getinfo` shows IPv6 not disabled). |
| 7 | Disconnect a real VPN (FortiClient/OpenVPN) that leaves the network degraded, then Fix. | Same as step 5: safe, sequential, verified, connectivity restored — and if a tunnel process is still running the primary-service cycle is **skipped** (log: planner `allowEscalation=false`). |

## Pass criteria (Phase 5)

- **Detected:** step 1/2 produce a visible "Network" issue + notification with **no** auto-fix.
- **Never breaks a working network:** step 4 makes zero changes.
- **Safe + effective:** step 5/7 restore connectivity via sequential, verified steps and stop early once healthy.
- **Never offline:** step 6 — the primary service stays enabled and IPv6 is never left disabled, at all times.

## If it fails

- "Network" entry never appears → the installed build predates Phase 5; reinstall the new build
  (`make app` + reinstall). Confirm with `make logs` that you see `[VPNDetector] Network-health issues:`.
- Connectivity not restored → read the `[SafeFix]` lines in `make logs`; the final line names the
  steps that ran and the residual `route=`/`dns=` state. No destructive change should have occurred.
- Left offline at any point → this is a regression; capture `make logs` and `route -n get default` /
  `networksetup -listallnetworkservices` output.

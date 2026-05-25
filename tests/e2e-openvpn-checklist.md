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

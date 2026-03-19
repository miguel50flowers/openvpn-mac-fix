# Market Research — macOS VPN & Network Repair Tool

> **Date:** March 2026
> **Objective:** Map the VPN landscape on macOS, identify recurring problems users face, and validate the market gap for a dedicated "VPN / network fixer" tool.

---

## 1. Top 15 VPN Clients on macOS

### Consumer VPN Clients

| # | Client | Protocol(s) | Est. Market Share | macOS-Specific Issues |
|---|--------|-------------|-------------------|----------------------|
| 1 | **NordVPN** | NordLynx (WireGuard), OpenVPN, IKEv2 | ~30% consumer | Kill switch leaves pf rules after crash; DNS leak on Wi-Fi switch; Network Extension conflicts on macOS 14+ |
| 2 | **ExpressVPN** | Lightway, OpenVPN, IKEv2 | ~20% consumer | Split tunneling unsupported on macOS; stale routes after sleep/wake; DNS resolver override persists after disconnect |
| 3 | **Surfshark** | WireGuard, OpenVPN, IKEv2 | ~12% consumer | Proxy settings left in System Preferences; utun interfaces not cleaned up; occasional IPv6 leak |
| 4 | **CyberGhost** | WireGuard, OpenVPN, IKEv2 | ~8% consumer | High CPU usage from helper daemon; stale Network Extension entries; DNS not restored after crash |
| 5 | **Proton VPN** | WireGuard, OpenVPN, IKEv2, Stealth | ~7% consumer | Kill switch (pf-based) survives app crash; Always-on VPN leaves routes permanently; split tunneling limited on macOS |
| 6 | **Mullvad VPN** | WireGuard, OpenVPN | ~3% consumer | Aggressive pf firewall rules persist; DNS hijacking after disconnect; utun interface leak |
| 7 | **Private Internet Access** | WireGuard, OpenVPN | ~5% consumer | Route table pollution (0/1, 128.0/1 pattern); DNS leak on reconnect; proxy settings stuck |
| 8 | **IPVanish** | WireGuard, OpenVPN, IKEv2 | ~4% consumer | DHCP lease issues after disconnect; mDNSResponder conflict; slow DNS restoration |
| 9 | **Windscribe** | WireGuard, OpenVPN, IKEv2, Stealth | ~3% consumer | Firewall mode leaves pf rules; split tunneling broken on Sonoma+; DNS leak on network switch |
| 10 | **TunnelBear** | OpenVPN, IKEv2 | ~2% consumer | Minimal macOS issues but stale routes on unclean disconnect; no kill switch cleanup |

### Enterprise VPN Clients

| # | Client | Protocol(s) | Est. Enterprise Share | macOS-Specific Issues |
|---|--------|-------------|----------------------|----------------------|
| 11 | **Cisco AnyConnect** | SSL/TLS, IPSec, DTLS | ~35% enterprise | Network Extension state corruption; posture assessment stalls; split tunnel route conflicts; ac_webhelper high CPU |
| 12 | **Palo Alto GlobalProtect** | SSL, IPSec | ~25% enterprise | PanGPS daemon persists after disconnect; HIP check failures on macOS upgrades; route table corruption; gateway-specific pf rules |
| 13 | **Pulse Secure / Ivanti Connect** | SSL, IPSec | ~15% enterprise | Host Checker conflicts with macOS Gatekeeper; DNS search domain corruption; JAMF MDM conflicts |
| 14 | **Zscaler Client Connector** | DTLS, TLS | ~10% enterprise | PAC file proxy settings persist; localhost proxy (9000) stays bound; tunnel interface not cleaned; interop issues with other VPNs |
| 15 | **FortiClient** | SSL, IPSec | ~10% enterprise | DNS forwarder persists after disconnect; route table not cleaned on force-quit; Network Extension issues on Sequoia |

---

## 2. Common Problems by Category

### 2.1 DNS Issues

| Problem | Description | Affected Clients | Severity |
|---------|-------------|-------------------|----------|
| **DNS leak** | DNS queries bypass VPN tunnel, exposing real DNS to ISP | Nord, Express, Surfshark, PIA, Windscribe | Critical |
| **DNS not restored** | After disconnect, DNS points to VPN server (now unreachable) → no internet | All clients | High |
| **mDNSResponder conflict** | VPN modifies mDNSResponder config; on disconnect, Bonjour/local DNS breaks | CyberGhost, IPVanish, FortiClient | Medium |
| **DNS search domain pollution** | VPN appends corporate domains to search list; not cleaned on disconnect | AnyConnect, GlobalProtect, Pulse Secure | Medium |
| **Split DNS failure** | DNS queries intended for corporate domains leak to public resolver | AnyConnect, GlobalProtect, Zscaler | High |

### 2.2 Route Table Corruption

| Problem | Description | Affected Clients | Severity |
|---------|-------------|-------------------|----------|
| **Stale 0/1 + 128.0/1 routes** | OpenVPN-style route hijack persists after disconnect | OpenVPN, PIA, TunnelBear, Tunnelblick | Critical |
| **Default gateway overwritten** | VPN replaces default route and doesn't restore on disconnect | All clients (crash scenario) | Critical |
| **Split tunnel route leak** | Routes for specific subnets persist, causing partial connectivity | AnyConnect, GlobalProtect, Pulse | High |
| **Metric conflict** | Multiple routes compete for default route with wrong metrics | WireGuard + OpenVPN coexistence | Medium |
| **IPv6 route leak** | IPv6 default route persists even after IPv4 tunnel is torn down | Mullvad, Proton, NordVPN | Medium |

### 2.3 Kill Switch / Firewall Issues

| Problem | Description | Affected Clients | Severity |
|---------|-------------|-------------------|----------|
| **pf rules persist** | Kill switch adds pf (packet filter) rules that survive VPN crash → no internet | NordVPN, Mullvad, Proton, Windscribe | Critical |
| **pf anchor stale** | VPN creates pf anchor (e.g., `com.apple/250.NordVPN`) that isn't flushed | NordVPN, Proton | High |
| **Application firewall conflict** | VPN's Network Extension conflicts with macOS Application Firewall | AnyConnect, CyberGhost | Medium |
| **Little Snitch interaction** | VPN kill switch + Little Snitch rules create double-block scenario | Any kill-switch VPN + Little Snitch | Medium |

### 2.4 Interface Issues

| Problem | Description | Affected Clients | Severity |
|---------|-------------|-------------------|----------|
| **Orphaned utun interfaces** | `utun3`, `utun4`, etc. persist without owning process | OpenVPN, WireGuard, Tunnelblick | High |
| **Orphaned ipsec interfaces** | `ipsec0` persists from IKEv2/IPSec VPNs | Built-in macOS VPN, AnyConnect | Medium |
| **Network Extension zombie** | System Extension listed but non-functional; new instance can't register | AnyConnect, GlobalProtect, FortiClient | High |
| **Interface MTU mismatch** | VPN sets lower MTU (e.g., 1400) that persists on physical interface | OpenVPN, WireGuard | Medium |

### 2.5 Proxy & System Configuration Issues

| Problem | Description | Affected Clients | Severity |
|---------|-------------|-------------------|----------|
| **Proxy settings stuck** | SOCKS/HTTP proxy configured by VPN persists in System Preferences | Surfshark, Zscaler, AnyConnect | High |
| **PAC URL persists** | Automatic proxy configuration URL points to dead VPN endpoint | Zscaler, GlobalProtect | High |
| **SCEP/certificate residue** | VPN-installed certificates remain in Keychain after uninstall | AnyConnect, Pulse Secure | Low |
| **SystemConfiguration plist corruption** | VPN crash corrupts `/Library/Preferences/SystemConfiguration/` plists | Any client (crash scenario) | Critical |

### 2.6 macOS Version-Specific Issues

| macOS Version | New Issues |
|---------------|------------|
| **Sequoia (15)** | Network Extension API changes break older VPN clients; new privacy prompts for local network access; tighter pf restrictions |
| **Sonoma (14)** | Split tunneling broken for several clients; WidgetKit conflicts with VPN status; Network Extension migration required |
| **Ventura (13)** | System Settings migration broke VPN preference panes; Network Extension deprecation warnings |
| **Monterey (12)** | IKEv2 regression in built-in VPN; DNS resolution order changed |

---

## 3. Non-VPN Network Problems on macOS

These are common network issues macOS users face that are **not VPN-related** but would benefit from a network repair tool.

| Problem | Symptoms | Root Cause | Manual Fix |
|---------|----------|------------|------------|
| **DNS cache stale** | Websites don't resolve despite working internet | mDNSResponder cached stale records | `sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder` |
| **DHCP lease stuck** | Self-assigned IP (169.254.x.x) or wrong subnet | DHCP lease not renewed after network change | `sudo ipconfig set en0 BOOTP && sudo ipconfig set en0 DHCP` |
| **Interface stuck down** | Wi-Fi shows connected but no traffic flows | Interface in inconsistent state after sleep/wake | `sudo ifconfig en0 down && sudo ifconfig en0 up` |
| **mDNSResponder crash loop** | Local network discovery fails; AirDrop broken | mDNSResponder in bad state | `sudo killall mDNSResponder` (launchd restarts it) |
| **Proxy settings stuck** | "No internet" despite connection; apps use wrong proxy | Manual or VPN-set proxy not cleared | System Preferences → Network → Advanced → Proxies → clear all |
| **pf firewall blocking** | Outbound traffic silently dropped | Stale pf rules from VPN or security tool | `sudo pfctl -d` to disable or `sudo pfctl -F all` to flush rules |
| **SystemConfiguration corruption** | Network preferences panel empty or broken | Corrupted plists in SystemConfiguration | Delete plists, reboot (⚠️ destructive) |
| **IPv6 connectivity broken** | Some sites unreachable; slow connections | IPv6 misconfigured or ISP issues | Disable IPv6 per interface via `networksetup` |
| **MTU too low** | Downloads stall; VoIP choppy; SSH hangs | VPN left reduced MTU on physical interface | `sudo ifconfig en0 mtu 1500` |
| **Wi-Fi auth loop** | Captive portal won't appear; keeps asking for password | Keychain entry conflict or DHCP issue | Delete saved network, flush DHCP, rejoin |

---

## 4. Error Tables by VPN Client

### 4.1 OpenVPN / Tunnelblick

| Error / Symptom | Cause | Fix |
|-----------------|-------|-----|
| No internet after disconnect | Stale routes 0/1 + 128.0/1 | Delete routes: `sudo route delete -net 0.0.0.0/1` and `128.0.0.0/1`; restore default gateway |
| DNS not resolving | `/etc/resolv.conf` or scutil DNS points to VPN server | Flush DNS, restore DHCP DNS via `scutil` |
| `utun2` persists | Process died without teardown | `sudo ifconfig utun2 destroy` |
| "TLS handshake failed" | Clock skew or certificate expired | Check system time; renew cert |
| "Cannot allocate TUN/TAP" | Too many orphaned utun interfaces | Destroy orphaned interfaces, reboot if needed |

### 4.2 WireGuard

| Error / Symptom | Cause | Fix |
|-----------------|-------|-----|
| No internet after deactivation | AllowedIPs routes (0.0.0.0/0) persist | Delete stale routes; flush DNS |
| DNS leak | VPN DNS not set as primary | Configure DNS via `scutil` or `networksetup` |
| `utun` interface persists | WireGuard app crashed or force-quit | `sudo ifconfig utunX destroy` |
| "Unable to create WireGuard adapter" | Network Extension conflict | Remove conflicting extensions; reboot |
| High latency after disconnect | MTU set to 1280 persists | `sudo ifconfig en0 mtu 1500` |

### 4.3 Cisco AnyConnect

| Error / Symptom | Cause | Fix |
|-----------------|-------|-----|
| "VPN Service not available" | vpnagentd crashed | `sudo launchctl kickstart -kp system/com.cisco.anyconnect.vpnagentd` |
| No internet (split tunnel) | Stale routes to corporate subnets | Delete routes matching corporate IP ranges |
| Host scan failure | Posture module conflicts with macOS update | Reinstall posture module; update AnyConnect |
| Network Extension "waiting to connect" | System Extension approval pending or corrupted | System Preferences → Privacy → re-approve; or remove and reinstall |
| ac_webhelper 100% CPU | Web-based auth portal stuck in loop | `killall ac_webhelper`; clear AnyConnect profile cache |
| DNS search domains persist | acs-resolver config not cleaned | `sudo scutil` → remove SearchDomains; restart mDNSResponder |

### 4.4 NordVPN / ExpressVPN / Surfshark

| Error / Symptom | Cause | Fix |
|-----------------|-------|-----|
| No internet after crash (Nord) | pf kill switch rules persist | `sudo pfctl -F all && sudo pfctl -d`; verify `/etc/pf.conf` is clean |
| DNS leak (all) | DNS resolver not properly set via Network Extension | Flush DNS; verify `scutil --dns` shows correct servers |
| "Unable to connect" after update | Network Extension needs re-approval | System Preferences → Privacy & Security → allow extension |
| Proxy settings stuck (Surfshark) | SOCKS5 proxy configured in System Preferences | Clear proxy settings via `networksetup -setsocksfirewallproxystate <service> off` |
| ExpressVPN "not connected" but routes exist | Lightway protocol partial teardown | Kill Lightway process; clean routes; flush DNS |

### 4.5 Palo Alto GlobalProtect

| Error / Symptom | Cause | Fix |
|-----------------|-------|-----|
| No internet after disconnect | PanGPS daemon still holding routes | `sudo killall PanGPS`; clean routes |
| "Gateway not responding" | HIP (Host Integrity Profile) check failure | Check macOS version compatibility; update GlobalProtect |
| DNS not restored | GlobalProtect DNS config persists in scutil | `sudo scutil` → delete VPN DNS configuration |
| "Unable to connect: host check" | MDM or compliance check fails after macOS update | Re-enroll device; update GlobalProtect client |
| PanGPS high CPU | Daemon in reconnection loop | `sudo launchctl unload /Library/LaunchDaemons/com.paloaltonetworks.pangps.plist`; relaunch manually |

---

## 5. Market Gap Analysis

### Is there a "VPN Fixer" tool for macOS?

**No.** After extensive research, there is no existing tool whose primary purpose is to detect and fix the problems that VPN clients leave behind on macOS.

| Tool | What It Does | Fixes VPN Issues? | Why It's Not a Competitor |
|------|-------------|-------------------|--------------------------|
| **Little Snitch** | Application-level firewall & network monitor | ❌ No | Monitors traffic; doesn't repair VPN damage. Can actually *conflict* with VPN kill switches |
| **Tunnelblick** | Open-source OpenVPN client | ⚠️ Partially (own tunnels only) | Only manages its own OpenVPN connections; no cross-client repair |
| **VPN Tracker** | Multi-protocol VPN client | ❌ No | VPN *client*, not a fixer. Manages connections, not repairs |
| **Viscosity** | Premium OpenVPN client | ⚠️ Partially (own tunnels only) | Better teardown than Tunnelblick but only for its own connections |
| **Wireshark** | Packet capture & network analysis | ❌ No | Diagnostic only; no repair capabilities |
| **Network Radar** | Network scanner | ❌ No | Scans for devices on network; no repair |
| **WiFi Explorer** | Wi-Fi analyzer | ❌ No | Analyzes Wi-Fi channels/signal; no VPN awareness |
| **NetSpot** | Wi-Fi site survey | ❌ No | Physical Wi-Fi coverage mapping; no VPN relevance |
| **Trip Mode** | Data usage monitor | ❌ No | Limits app data usage; no repair |
| **CleanMyMac (Network module)** | General Mac maintenance | ⚠️ Minimal | DNS flush only; no route/pf/interface repair |

### The Gap

```
                    VPN Management    Network Monitoring    VPN/Network REPAIR
                    ──────────────    ──────────────────    ──────────────────
Little Snitch              ❌                ✅                    ❌
Tunnelblick                ✅                ❌                    ⚠️ (self only)
VPN Tracker                ✅                ❌                    ❌
Wireshark                  ❌                ✅                    ❌
CleanMyMac                 ❌                ⚠️                    ⚠️ (DNS only)
>>> OUR TOOL <<<           ❌                ✅                    ✅  ← UNIQUE
```

**Our tool is NOT a VPN client.** It's the tool you use when your VPN client breaks your network. No one else occupies this space.

---

## 6. User Pain Points (from forums, Reddit, Stack Overflow)

Common user complaints aggregated from public forums:

1. **"VPN disconnected and now I have no internet"** — The #1 complaint across all VPN subreddits. Users resort to rebooting.
2. **"I uninstalled [VPN] but my DNS is still broken"** — VPN left DNS configuration in system that wasn't cleaned up.
3. **"Kill switch won't turn off"** — pf rules persist even after VPN app is quit/uninstalled.
4. **"Mac shows connected to Wi-Fi but no internet"** — Often caused by stale routes, DNS, or proxy from VPN.
5. **"I need to restart my Mac every time VPN disconnects"** — Users have no other solution than rebooting.
6. **"AnyConnect broke my network after macOS update"** — Enterprise users hit this after every major macOS release.
7. **"Multiple VPNs installed and nothing works"** — Route/DNS conflicts between personal and corporate VPNs.

### Key Insight

> **Users currently reboot their Mac to fix VPN-caused network problems.** There is no tool that provides a faster, targeted fix. This is our opportunity.

---

## 7. Addressable Market

| Segment | Size | Pain Level | Willingness to Pay |
|---------|------|------------|-------------------|
| **macOS VPN users (consumer)** | ~50M+ globally | Medium-High | $5-15 one-time or $2-5/month |
| **macOS VPN users (enterprise)** | ~20M+ globally | Very High | $20-50/seat/year (IT departments) |
| **macOS users with network issues (no VPN)** | ~100M+ | Medium | $5-10 one-time |
| **IT helpdesk / MSP** | Thousands of orgs | Very High | $100-500/year for bulk license |

### Revenue Model Options

- **Freemium**: Basic fix (current OpenVPN fix) free; advanced diagnostics + multi-VPN + network repair = paid
- **One-time purchase**: $9.99-14.99 on Mac App Store
- **Subscription**: $2.99/month or $19.99/year for pro features
- **Enterprise**: Per-seat licensing with management console

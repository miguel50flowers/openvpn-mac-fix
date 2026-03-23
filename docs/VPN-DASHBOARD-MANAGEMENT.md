# VPN Dashboard Management — Research & Design

> Feature design document for hiding/removing VPN clients from the Dashboard and manually adding custom VPN clients.

---

## 1. Hide/Remove VPN from Dashboard

### Goal

Allow users to hide VPN clients they don't want to see or manage in the Dashboard. Hidden clients are not deleted — they can be restored at any time via a "Manage VPNs" panel.

### Data Model

Extend `AppPreferences` (`app/VPNFix/Models/AppPreferences.swift`) with a new `@AppStorage` property:

```swift
/// Set of VPNClientType raw values that the user has hidden from the Dashboard.
@AppStorage("hiddenClients") var hiddenClients: String = "[]"
// Stored as JSON array of VPNClientType raw values, same pattern as dismissedIssues.
```

Helper methods on `AppPreferences`:

```swift
func hideClient(_ client: VPNClientType)
func unhideClient(_ client: VPNClientType)
func isHidden(_ client: VPNClientType) -> Bool
func hiddenClientTypes() -> Set<VPNClientType>
```

### Dashboard Integration

In `DashboardViewModel` (`app/VPNFix/ViewModels/DashboardViewModel.swift`):

- After receiving `[VPNClientStatus]` from XPC, filter out clients where `preferences.isHidden(status.clientType)`.
- Expose a `@Published var hiddenCount: Int` so the UI can show "N hidden" badge.

### UI Design

| Component | Location | Behavior |
|-----------|----------|----------|
| Context menu on `VPNClientCard` | `VPNClientCard.swift` | Right-click → "Hide from Dashboard" |
| Swipe action (optional) | `VPNClientCard.swift` | Swipe left → hide icon |
| "Manage VPNs" button | `VPNClientSection.swift` header | Opens sheet listing all detected + hidden clients with toggles |
| "Show All" quick action | `VPNClientSection.swift` | One-click to unhide all |
| Hidden count badge | `VPNClientSection.swift` header | "2 hidden" label next to "Manage VPNs" |

**UI Pattern Reference:** [Lulu Firewall](https://github.com/objective-see/LuLu) uses a user-controlled list where items can be toggled on/off without deletion. This avoids modal confirmation dialogs and gives users confidence that hiding is reversible.

### Edge Cases

- If a hidden VPN has **critical issues** (e.g., `killSwitchActive` blocking all traffic), consider showing a warning badge even while hidden, or auto-unhiding it.
- Hiding should persist across app restarts (UserDefaults).
- The "Manage VPNs" panel should show both currently detected and previously-seen-but-now-uninstalled clients.

---

## 2. Manually Add VPN Client

### Goal

Allow users to add a VPN client that isn't auto-detected. Two approaches:

1. **Select from known list** — Pick from the 17 supported `VPNClientType` entries (useful if auto-detection missed an installed client).
2. **Browse for .app** — Use an open panel to select any `.app` bundle, creating a custom VPN entry.

### macOS APIs for App Detection

#### NSWorkspace (AppKit)

```swift
import AppKit

// Check if a specific app is installed by bundle ID
let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.expressvpn.ExpressVPN")

// List all running applications
let running = NSWorkspace.shared.runningApplications
```

- **Documentation:** [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace)
- **Limitation:** `runningApplications` only returns currently running apps. For installed apps, use Launch Services or scan `/Applications`.

#### Launch Services (CoreServices)

```swift
import CoreServices

// Find all installed copies of an app by bundle ID
var urls: Unmanaged<CFArray>?
let status = LSCopyApplicationURLsForBundleIdentifier(
    "com.nordvpn.osx" as CFString,
    nil
)
if let urls = status?.takeRetainedValue() as? [URL] {
    // urls contains all installed locations
}
```

- **Documentation:** [LSCopyApplicationURLsForBundleIdentifier](https://developer.apple.com/documentation/coreservices/1449290-lscopyapplicationurlsforbundleid)
- **Use case:** Validate that a user-selected VPN app actually exists at the specified path.

#### NSMetadataQuery (Spotlight)

```swift
import Foundation

let query = NSMetadataQuery()
query.predicate = NSPredicate(format: "kMDItemContentType == 'com.apple.application-bundle'")
query.searchScopes = ["/Applications"]
query.start()
// Observe NSMetadataQueryDidFinishGathering notification for results
```

- **Documentation:** [NSMetadataQuery](https://developer.apple.com/documentation/foundation/nsmetadataquery)
- **Use case:** Discover all installed `.app` bundles to present as a browseable list.

#### NSOpenPanel (User Selection)

```swift
let panel = NSOpenPanel()
panel.allowedContentTypes = [.applicationBundle]
panel.directoryURL = URL(fileURLWithPath: "/Applications")
panel.canChooseDirectories = false
panel.allowsMultipleSelection = false
panel.message = "Select a VPN application to add"

if panel.runModal() == .OK, let url = panel.url {
    // Extract bundle ID, name, icon from url
    let bundle = Bundle(url: url)
    let bundleID = bundle?.bundleIdentifier
    let name = bundle?.infoDictionary?["CFBundleName"] as? String
}
```

- **Use case:** Let the user browse and pick any `.app` they consider a VPN client.

### Data Model for Custom VPN Entries

New `CustomVPNEntry` struct in `app/Shared/`:

```swift
struct CustomVPNEntry: Codable, Identifiable, Sendable {
    let id: UUID
    var displayName: String        // e.g., "My Corporate VPN"
    var bundleIdentifier: String?  // e.g., "com.example.vpn"
    var appPath: String            // e.g., "/Applications/MyVPN.app"
    var interfaceType: String?     // e.g., "utun", "ppp", "ipsec"
    var processName: String?       // e.g., "myvpnd" (for process detection)
    var dateAdded: Date
}
```

Storage in `AppPreferences`:

```swift
@AppStorage("customVPNEntries") var customVPNEntries: String = "[]"
// JSON-encoded [CustomVPNEntry]
```

### Custom VPN Detection

New `CustomVPNDetector` in `app/VPNFixHelper/Detectors/`:

- Iterates over `[CustomVPNEntry]` from preferences.
- For each entry:
  1. Check if app exists at `appPath` (via `FileManager.default.fileExists`).
  2. Check if `processName` is in `cache.runningProcesses`.
  3. Check routing table for any `utun`/`ppp`/`ipsec` interfaces (generic detection).
- Returns `VPNClientStatus` with `clientType = .custom` (requires adding `.custom(String)` case to `VPNClientType` or a separate model).

### UI Design — "Add VPN" Flow

```
Dashboard Header
├── [+ Add VPN] button
│   └── Sheet: "Add VPN Client"
│       ├── Tab 1: "From Known List"
│       │   └── List of 17 VPNClientType entries
│       │       ├── Shows install status (detected / not detected)
│       │       ├── Select → force-adds to dashboard even if not auto-detected
│       │       └── Useful for: VPN installed in non-standard path
│       │
│       └── Tab 2: "Custom VPN"
│           ├── [Browse...] button → NSOpenPanel for .app selection
│           ├── Auto-fills: name, bundle ID, icon from selected .app
│           ├── Manual fields: process name (optional), interface type (dropdown)
│           └── [Add] button → saves CustomVPNEntry to preferences
```

### Edge Cases

- **Duplicate detection:** If a manually added VPN is later auto-detected, merge entries (prefer auto-detection data, keep user's custom name if set).
- **App moved/deleted:** On scan, check if `appPath` still exists. Show "App not found" warning but don't auto-remove.
- **Permissions:** `NSOpenPanel` works without special entitlements. `NSMetadataQuery` works in sandboxed apps for `/Applications`.
- **VPNClientType extension:** Adding custom VPN support may require either:
  - A new `.custom` case in the `VPNClientType` enum, or
  - A parallel `CustomVPNClientStatus` model that renders the same `VPNClientCard` UI.

---

## 3. References

| Resource | URL |
|----------|-----|
| NSWorkspace (Apple) | https://developer.apple.com/documentation/appkit/nsworkspace |
| LSCopyApplicationURLsForBundleIdentifier (Apple) | https://developer.apple.com/documentation/coreservices/1449290-lscopyapplicationurlsforbundleid |
| NSMetadataQuery (Apple) | https://developer.apple.com/documentation/foundation/nsmetadataquery |
| NETunnelProviderManager (Apple) | https://developer.apple.com/documentation/networkextension/netunnelprovidermanager |
| VPN Overview — Apple Deployment | https://support.apple.com/guide/deployment/vpn-overview-depae3d361d0/web |
| Lulu Firewall (open-source, UI pattern reference) | https://github.com/objective-see/LuLu |
| Little Snitch (commercial, UI pattern reference) | https://www.obdev.at/products/littlesnitch |

---

## 4. Key Files to Modify (When Implementing)

| File | Change |
|------|--------|
| `app/Shared/VPNClientType.swift` | Add `.custom` case or extend for user-added clients |
| `app/Shared/VPNClientStatus.swift` | Support custom VPN entries |
| `app/VPNFix/Models/AppPreferences.swift` | Add `hiddenClients` and `customVPNEntries` storage |
| `app/VPNFix/ViewModels/DashboardViewModel.swift` | Filter hidden clients, include custom entries |
| `app/VPNFix/Views/Dashboard/VPNClientSection.swift` | "Manage VPNs" button, hidden count badge |
| `app/VPNFix/Views/Dashboard/VPNClientCard.swift` | Context menu "Hide from Dashboard" |
| `app/VPNFix/Views/Dashboard/ManageVPNsView.swift` | New view: toggle visibility, add custom VPN |
| `app/VPNFixHelper/Detectors/CustomVPNDetector.swift` | New detector for user-added VPN entries |
| `app/VPNFixHelper/VPNDetector.swift` | Include custom detector in detection cycle |

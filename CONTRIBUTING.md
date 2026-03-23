# Contributing to VPN Fix

Thanks for your interest in contributing! This guide covers everything you need to get up and running.

## Getting Started

### Prerequisites

- **macOS 13** (Ventura) or later
- **Xcode 15+** with Command Line Tools (`xcode-select --install`)
- **XcodeGen** -- `brew install xcodegen`

## Building Locally

```bash
git clone https://github.com/miguel50flowers/openvpn-mac-fix.git
cd openvpn-mac-fix/app
xcodegen generate
open VPNFix.xcodeproj
```

Or via Makefile from the repo root:

```bash
make app    # Builds unsigned universal binary
```

## Running Tests

```bash
xcodebuild test \
  -project app/VPNFix.xcodeproj \
  -scheme VPNFix \
  -destination 'platform=macOS'
```

## Project Structure

| Path | Description |
|------|-------------|
| `app/VPNFix/` | Main SwiftUI app |
| `app/VPNFixHelper/` | Privileged helper daemon (XPC) |
| `app/Shared/` | Shared models and protocols |
| `app/VPNFixTests/` | Unit tests |
| `scripts/` | Shell scripts for VPN monitoring and fixing |

## Pull Request Guidelines

1. **Fork the repo** and create a feature branch (`feature/your-change`, `fix/your-fix`).
2. **Follow existing code patterns** -- SwiftUI for views, services as singletons.
3. **Update `CHANGELOG.md`** under `[Unreleased]` with a summary of your changes.
4. **Ensure CI passes** -- the workflow runs both build and tests automatically.
5. **PRs are reviewed by code owners** before merging.

## Reporting Issues

Use the **Report Issue** button inside the app (About section) to automatically include device info and logs, or open an issue directly on [GitHub](https://github.com/miguel50flowers/openvpn-mac-fix/issues).

# ADR-004: Ad-hoc Code Signing

## Status
Active (Developer ID pending)

## Context
macOS requires code signing for XPC services, Gatekeeper, and notarization.

## Decision
Use ad-hoc signing (`CODE_SIGN_IDENTITY="-"`) for all builds.

## Rationale
- No Apple Developer ID has been obtained yet.
- Ad-hoc signing allows XPC communication to work locally.
- The app requires "right-click → Open" on first launch to bypass Gatekeeper.

## Consequences
- Cannot notarize the app (users see "unidentified developer" warning).
- XPC code signature verification uses bundle ID only (not team ID or certificate hash).
- Cannot distribute via Mac App Store.
- Sparkle auto-updates use EdDSA signatures for integrity, partially compensating for lack of code signing.

## Migration Plan
Obtain Apple Developer ID → sign with `Developer ID Application` → notarize → strengthen XPC verification to include team ID.

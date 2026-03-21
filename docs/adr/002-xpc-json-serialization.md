# ADR-002: JSON Strings over XPC instead of Typed Objects

## Status
Active

## Context
The XPC protocol between the app and helper daemon needs to transmit complex Swift types (`[VPNClientStatus]`, `NetworkDiagnostics`).

## Decision
Encode complex types as JSON strings on the helper side and decode them on the app side. The `@objc` XPC protocol uses `String` parameters.

## Rationale
- XPC protocols must be `@objc` compatible, which excludes Swift generics, enums with associated values, and custom structs.
- `NSSecureCoding` conformance would require converting all Shared models to `NSObject` subclasses, losing Swift value-type benefits (Codable, Sendable, struct semantics).
- JSON encoding/decoding is already proven reliable in the codebase with `Codable` conformance on all shared types.

## Consequences
- Loss of compile-time contract verification between app and helper (mitigated by shared `Codable` types and comprehensive unit tests).
- Manual JSON encode/decode at each call site (mitigated by typed convenience methods in `XPCClient`: `detectAllVPNClientsTyped`, `getNetworkDiagnosticsTyped`).
- Error responses must be handled by the decoder (mitigated by `XPCError` type).

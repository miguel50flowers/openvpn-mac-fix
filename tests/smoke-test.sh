#!/bin/bash
# smoke-test.sh — fast, no-sudo verification that the VPN-Fix core is wired up correctly.
#
# Checks, in order:
#   1. CORE LOGIC  — compiles the pure Shared types + tests/logic-check.swift with swiftc
#                    and runs them (VPN state classification + auto-fix decision). REQUIRED.
#   2. SHELL LINT  — `bash -n` (and shellcheck if installed) on the shell scripts. REQUIRED.
#   3. APP BUILD   — best-effort `make app` + bundle wiring assertions. SKIPPED (not failed)
#                    if the local Xcode cannot initialize xcodebuild (e.g. needs
#                    `sudo xcodebuild -runFirstLaunch`); CI runs the full build + XCTest.
#
# Usage:  tests/smoke-test.sh        (or: make smoke)
#         SKIP_BUILD=1 tests/smoke-test.sh   to skip step 3 entirely.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
SKIP=0
pass() { echo "  ✓ $*"; PASS=$((PASS + 1)); }
fail() { echo "  ✗ FAIL: $*"; FAIL=$((FAIL + 1)); }
skip() { echo "  ⤼ SKIP: $*"; SKIP=$((SKIP + 1)); }

echo "== VPN-Fix smoke test =="
echo "repo: $ROOT"

# ---------------------------------------------------------------------------
echo ""
echo "[1/3] Core logic (pure Shared types via swiftc)"
if ! command -v swiftc >/dev/null 2>&1; then
    fail "swiftc not found — cannot verify core logic"
else
    if swiftc -parse-as-library \
        "$ROOT/app/Shared/VPNState.swift" \
        "$ROOT/app/Shared/AutoFixPolicy.swift" \
        "$ROOT/app/Shared/VPNStateClassifier.swift" \
        "$ROOT/app/Shared/AutoFixCoordinator.swift" \
        "$ROOT/tests/logic-check.swift" \
        -o "$TMP/logiccheck" 2>"$TMP/logic_compile.log"; then
        if "$TMP/logiccheck"; then
            pass "core logic checks passed"
        else
            fail "core logic checks failed (see output above)"
        fi
    else
        fail "core logic did not compile"
        cat "$TMP/logic_compile.log"
    fi

    # Network detection + planner logic (Phase 5)
    if swiftc -parse-as-library \
        "$ROOT/app/Shared/VPNIssue.swift" \
        "$ROOT/app/Shared/NetworkHealth.swift" \
        "$ROOT/app/Shared/NetworkFixPlanner.swift" \
        "$ROOT/tests/network-logic-check.swift" \
        -o "$TMP/netlogiccheck" 2>"$TMP/netlogic_compile.log"; then
        if "$TMP/netlogiccheck"; then
            pass "network detection + planner checks passed"
        else
            fail "network detection + planner checks failed (see output above)"
        fi
    else
        fail "network logic did not compile"
        cat "$TMP/netlogic_compile.log"
    fi

    # Safe-fix executor sequencing (stops the moment connectivity returns; never over-fixes)
    if swiftc -parse-as-library \
        "$ROOT/app/Shared/VPNIssue.swift" \
        "$ROOT/app/Shared/NetworkHealth.swift" \
        "$ROOT/app/Shared/NetworkFixPlanner.swift" \
        "$ROOT/app/Shared/SafeFixExecutor.swift" \
        "$ROOT/tests/safe-executor-check.swift" \
        -o "$TMP/safeexec" 2>"$TMP/safeexec_compile.log"; then
        if "$TMP/safeexec"; then
            pass "safe-fix executor checks passed"
        else
            fail "safe-fix executor checks failed (see output above)"
        fi
    else
        fail "safe-fix executor did not compile"
        cat "$TMP/safeexec_compile.log"
    fi
fi

# ---------------------------------------------------------------------------
echo ""
echo "[2/3] Shell script lint"
SHELL_SCRIPTS=("$ROOT/scripts/fix-vpn-disconnect.sh" "$ROOT/scripts/vpn-monitor.sh" "$SCRIPT_DIR"/*.sh)
for s in "${SHELL_SCRIPTS[@]}"; do
    [ -f "$s" ] || continue
    name="$(basename "$s")"
    if bash -n "$s" 2>"$TMP/lint.log"; then
        pass "bash -n: $name"
    else
        fail "bash -n: $name"
        cat "$TMP/lint.log"
    fi
done
if command -v shellcheck >/dev/null 2>&1; then
    for s in "${SHELL_SCRIPTS[@]}"; do
        [ -f "$s" ] || continue
        if shellcheck -S error "$s" >/dev/null 2>&1; then
            pass "shellcheck: $(basename "$s")"
        else
            fail "shellcheck: $(basename "$s")"
        fi
    done
else
    skip "shellcheck not installed (bash -n covered syntax)"
fi

# ---------------------------------------------------------------------------
echo ""
echo "[3/3] App build + bundle wiring (best-effort)"
if [ "${SKIP_BUILD:-0}" = "1" ]; then
    skip "build skipped (SKIP_BUILD=1)"
elif ! command -v xcodebuild >/dev/null 2>&1; then
    skip "xcodebuild not available"
else
    BUILD_LOG="$TMP/build.log"
    ( cd "$ROOT" && make app ) >"$BUILD_LOG" 2>&1
    BUILD_EXIT=$?
    if grep -qE "runFirstLaunch|failed to load a required plug-in" "$BUILD_LOG"; then
        skip "local Xcode cannot init xcodebuild — run 'sudo xcodebuild -runFirstLaunch'. CI covers the full build + XCTest."
    elif [ "$BUILD_EXIT" -ne 0 ]; then
        fail "make app failed (exit $BUILD_EXIT)"
        tail -25 "$BUILD_LOG"
    else
        pass "make app succeeded"
        APP="$ROOT/build/DerivedData/Build/Products/Release/VPN Fix.app"
        RES="$APP/Contents/Resources"
        [ -d "$APP" ] && pass "app bundle exists" || fail "app bundle missing at $APP"
        [ -f "$RES/fix-vpn-disconnect.sh" ] && pass "fix script bundled" || fail "fix script not bundled"
        if [ -f "$RES/fix-vpn-disconnect.sh" ]; then
            if grep -q "__VERSION__" "$RES/fix-vpn-disconnect.sh"; then
                fail "fix script still contains __VERSION__ placeholder"
            else
                pass "fix script VERSION placeholder substituted"
            fi
        fi
        HELPER="$APP/Contents/Library/LaunchDaemons/com.miguel50flowers.VPNFix.helper.plist"
        [ -f "$HELPER" ] && pass "helper launchd plist bundled" || fail "helper launchd plist missing"
        if [ -d "$APP/Contents/MacOS" ] && ls "$APP/Contents/MacOS/" 2>/dev/null | grep -qi helper; then
            pass "helper executable embedded"
        else
            skip "helper executable not found by name (non-fatal)"
        fi
    fi
fi

# ---------------------------------------------------------------------------
echo ""
echo "== summary: $PASS passed, $FAIL failed, $SKIP skipped =="
[ "$FAIL" -eq 0 ] || exit 1
echo "SMOKE TEST PASSED"

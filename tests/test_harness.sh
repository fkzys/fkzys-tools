#!/usr/bin/env bash
# tests/test_harness.sh — Shared test harness for fkzys-tools
# Sourced by individual test files — NOT run directly.

set -uo pipefail
# Note: no -e. Tests must continue running when assertions fail
# so failures can be counted and reported by summary().

PASS=0
FAIL=0
TESTS=0

ok()   { PASS=$((PASS + 1)); TESTS=$((TESTS + 1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); TESTS=$((TESTS + 1)); echo "  ✗ $1"; }

section() { echo ""; echo "── $1 ──"; }

# ── Summary ──────────────────────────────────────────────────

summary() {
    local name="${0##*/}"
    echo ""
    echo "════════════════════════════════════"
    echo " ${name}: ${PASS} passed, ${FAIL} failed (total: ${TESTS})"
    echo "════════════════════════════════════"
    [[ $FAIL -ne 0 ]] && exit 1
    exit 0
}

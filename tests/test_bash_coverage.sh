#!/usr/bin/env bash
# tests/test_bash_coverage.sh — Tests for bash-coverage
# Run: bash tests/test_bash_coverage.sh

source "$(dirname "${BASH_SOURCE[0]}")/test_harness.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COVERAGE="${SCRIPT_DIR}/../bin/bash-coverage"

# ════════════════════════════════════════════════════════
# Basic: single command coverage
# ════════════════════════════════════════════════════════

section "Basic: single command"

# Create a simple script to cover
COVERED_SCRIPT=$(mktemp)
cat > "$COVERED_SCRIPT" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly VERSION=1.0.0

greet() {
    echo "Hello, $1"
}

add() {
    echo $(( $1 + $2 ))
}

case "${1:-}" in
    --help) echo "Usage: script"; exit 0 ;;
    -V|--version) echo "$VERSION"; exit 0 ;;
    *) greet "${1:-world}"; add 2 3; exit 0 ;;
esac
EOF
chmod +x "$COVERED_SCRIPT"

# Run coverage
output=$("$COVERAGE" -- bash "$COVERED_SCRIPT" test 2>&1)
echo "$output" | grep -q "Coverage Report" && ok "produces coverage report" || fail "no coverage report"
echo "$output" | grep -qF "$COVERED_SCRIPT" && ok "report includes covered script" || fail "script not in report"
rm -f "$COVERED_SCRIPT"

# ════════════════════════════════════════════════════════
# Coverage: percentage calculation
# ════════════════════════════════════════════════════════

section "Coverage: percentage"

# Fully covered script
FULL_COVER=$(mktemp)
cat > "$FULL_COVER" << 'EOF'
#!/bin/bash
echo "fully covered"
EOF
chmod +x "$FULL_COVER"

output=$("$COVERAGE" -- bash "$FULL_COVER" 2>&1)
echo "$output" | grep -qE '100%' && ok "shows 100% for fully covered script" || fail "not 100%"
rm -f "$FULL_COVER"

# Partially covered script (has unreachable code in case)
PARTIAL_COVER=$(mktemp)
cat > "$PARTIAL_COVER" << 'EOF'
#!/bin/bash
set -euo pipefail
case "${1:-}" in
    a) echo "branch a" ;;
    b) echo "branch b" ;;
esac
EOF
chmod +x "$PARTIAL_COVER"

output=$("$COVERAGE" -- bash "$PARTIAL_COVER" a 2>&1)
# Should not show 100% (branch b not covered)
! echo "$output" | grep -qE '100%' && ok "shows <100% for partial coverage" || fail "showed 100% for partial"
rm -f "$PARTIAL_COVER"

# ════════════════════════════════════════════════════════
# -p project mode: auto-discover tests
# ════════════════════════════════════════════════════════

section "ERROR: -p project mode"

PROJ_DIR=$(mktemp -d)
mkdir -p "$PROJ_DIR/tests"

# Simple inline test (no source — coverage works on direct execution)
cat > "$PROJ_DIR/tests/test.sh" << 'EOF'
#!/usr/bin/env bash
set -uo pipefail
greet() { echo "Hello"; }
math() { echo $(( 2 + 3 )); }
greet
math
EOF
chmod +x "$PROJ_DIR/tests/test.sh"

output=$("$COVERAGE" -p "$PROJ_DIR" 2>&1)
echo "$output" | grep -q "Coverage Report" && ok "project mode produces report" || fail "project mode no report"
rm -rf "$PROJ_DIR"

# ════════════════════════════════════════════════════════
# --help and -V
# ════════════════════════════════════════════════════════

section "CLI: --help and -V"

"$COVERAGE" --help >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 ]] && ok "--help exits 0" || fail "--help should exit 0"

"$COVERAGE" -V >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 ]] && ok "-V exits 0" || fail "-V should exit 0"

"$COVERAGE" -V 2>&1 | grep -qF "v0.1.0" && ok "-V shows version" || fail "-V missing version"

# ════════════════════════════════════════════════════════
# Syntax check
# ════════════════════════════════════════════════════════

section "Syntax"

bash -n "$COVERAGE" && ok "bash -n passes" || fail "bash -n fails"

# ════════════════════════════════════════════════════════
# Summary
# ════════════════════════════════════════════════════════

summary

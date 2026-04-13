#!/usr/bin/env bash
# tests/test_bash_lint.sh — Tests for bash-lint
# Run: bash tests/test_bash_lint.sh

source "$(dirname "${BASH_SOURCE[0]}")/test_harness.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINT="${SCRIPT_DIR}/../bin/bash-lint"

# Helper: run lint on a file
lint_file() {
    local file="$1"
    "$LINT" "$file" 2>&1
}

lint_project() {
    local dir="$1"
    "$LINT" -p "$dir" 2>&1
}

has_error() {
    local output="$1" code="$2"
    echo "$output" | grep -qF ":$code:"
}

has_warning() {
    local output="$1" code="$2"
    echo "$output" | grep -qF ":$code:"
}

has_info() {
    local output="$1" code="$2"
    echo "$output" | grep -qF ":$code:"
}

has_no_error() {
    local output="$1" code="$2"
    ! echo "$output" | grep -qF ":$code:"
}

has_no_warning() {
    local output="$1" code="$2"
    ! echo "$output" | grep -qF ":$code:"
}

# For tests that need a specific file type, create a mini-project
make_entry() {
    local dir="$1" name="${2:-app}"
    mkdir -p "$dir/bin"
    echo "$name"
}

make_lib() {
    local dir="$1" name="${2:-common.sh}"
    mkdir -p "$dir/lib"
    echo "$name"
}

make_test() {
    local dir="$1" name="${2:-test.sh}"
    mkdir -p "$dir/tests"
    echo "$name"
}

# ════════════════════════════════════════════════════════
# ERROR: ENTRY_STRICTNESS — set -euo pipefail
# ════════════════════════════════════════════════════════

section "ERROR: ENTRY_STRICTNESS"

PROJ=$(mktemp -d)
ENTRY=$(make_entry "$PROJ")

# Bad: entry point with no set
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
echo "hello"
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_error "$output" "ENTRY_STRICTNESS" && ok "detects entry without set -euo pipefail" || fail "missed entry without set -euo pipefail"

# Good: entry point with set -euo pipefail
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
echo "hello"
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_no_error "$output" "ENTRY_STRICTNESS" && ok "accepts entry with set -euo pipefail" || fail "flagged entry with set -euo pipefail"

# Good: guard script with explanatory comment
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
# Note: no "set -euo pipefail" — this script relies on conditional control flow incompatible with errexit
echo "guard"
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_no_error "$output" "ENTRY_STRICTNESS" && ok "accepts guard script with explanatory comment" || fail "flagged guard script"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# ERROR: VERIFY_LIB
# ════════════════════════════════════════════════════════

section "ERROR: VERIFY_LIB"

PROJ=$(mktemp -d)
ENTRY=$(make_entry "$PROJ")

# Bad: entry without verify-lib
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
source "/usr/lib/project/common.sh"
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_error "$output" "VERIFY_LIB" && ok "detects entry without verify-lib" || fail "missed entry without verify-lib"

# Good: entry with verify-lib + _src
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly LIBDIR="/usr/lib/project"
_src() { local p; p=$(verify-lib "$1" "$LIBDIR/") && source "$p" || exit 1; }
_src "${LIBDIR}/common.sh"
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_no_error "$output" "VERIFY_LIB" && ok "accepts entry with verify-lib + _src" || fail "flagged good verify-lib pattern"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# ERROR: CONFIG_EVAL
# ════════════════════════════════════════════════════════

section "ERROR: CONFIG_EVAL"

PROJ=$(mktemp -d)
ENTRY=$(make_entry "$PROJ")

# Bad: eval in non-test script
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
eval "$config_line"
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_error "$output" "CONFIG_EVAL" && ok "detects eval in non-test script" || fail "missed eval"

# Good: eval in test script
TEST_F=$(make_test "$PROJ")
cat > "$PROJ/tests/$TEST_F" << 'EOF'
#!/usr/bin/env bash
set -uo pipefail
eval "$config_line"
EOF
chmod +x "$PROJ/tests/$TEST_F"

output=$(lint_file "$PROJ/tests/$TEST_F")
has_no_error "$output" "CONFIG_EVAL" && ok "allows eval in test script" || fail "flagged eval in test script"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# ERROR: ERROR_STDERR
# ════════════════════════════════════════════════════════

section "ERROR: ERROR_STDERR"

PROJ=$(mktemp -d)
ENTRY=$(make_entry "$PROJ")

# Bad: ERROR message to stdout
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
echo "ERROR: something failed"
exit 1
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_error "$output" "ERROR_STDERR" && ok "detects ERROR message without stderr redirect" || fail "missed ERROR to stdout"

# Good: ERROR message to stderr
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
echo "ERROR: something failed" >&2
exit 1
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_no_error "$output" "ERROR_STDERR" && ok "accepts ERROR with >&2" || fail "flagged ERROR with >&2"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# ERROR: CHMOD_777
# ════════════════════════════════════════════════════════

section "ERROR: CHMOD_777"

PROJ=$(mktemp -d)
ENTRY=$(make_entry "$PROJ")

# Bad: chmod 777
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
chmod 777 /tmp/file
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_error "$output" "CHMOD_777" && ok "detects chmod 777" || fail "missed chmod 777"

# Good: chmod 755
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
chmod 755 /tmp/file
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_no_error "$output" "CHMOD_777" && ok "accepts chmod 755" || fail "flagged chmod 755"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# WARN: NO_INIT
# ════════════════════════════════════════════════════════

section "WARN: NO_INIT"

PROJ=$(mktemp -d)
ENTRY=$(make_entry "$PROJ")

# Bad: source common.sh without NO_INIT
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly LIBDIR="/usr/lib/project"
_src() { local p; p=$(verify-lib "$1" "$LIBDIR/") && source "$p" || exit 1; }
_src "${LIBDIR}/common.sh"
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_warning "$output" "NO_INIT" && ok "detects missing _*_NO_INIT" || fail "missed missing NO_INIT"

# Good: source common.sh with NO_INIT
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly _PROJECT_NO_INIT=1
readonly LIBDIR="/usr/lib/project"
_src() { local p; p=$(verify-lib "$1" "$LIBDIR/") && source "$p" || exit 1; }
_src "${LIBDIR}/common.sh"
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_no_warning "$output" "NO_INIT" && ok "accepts _*_NO_INIT before sourcing" || fail "flagged NO_INIT"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# WARN: CONFIG_WHITELIST / CONFIG_OWNERSHIP
# ════════════════════════════════════════════════════════

section "WARN: CONFIG_WHITELIST / CONFIG_OWNERSHIP"

PROJ=$(mktemp -d)
LIB=$(make_lib "$PROJ")

# Bad: load_config without whitelist + ownership
cat > "$PROJ/lib/$LIB" << 'EOF'
#!/usr/bin/env bash
load_config() {
    while IFS='=' read -r key value; do
        eval "$key=$value"
    done < "$CONFIG_FILE"
}
EOF

output=$(lint_file "$PROJ/lib/$LIB")
has_warning "$output" "CONFIG_WHITELIST" && ok "detects load_config without whitelist" || fail "missed config whitelist"
has_warning "$output" "CONFIG_OWNERSHIP" && ok "detects load_config without ownership check" || fail "missed config ownership"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# WARN: CLEANUP_TRAP
# ════════════════════════════════════════════════════════

section "WARN: CLEANUP_TRAP"

PROJ=$(mktemp -d)
ENTRY=$(make_entry "$PROJ")

# Bad: entry creates temp without trap
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly LIBDIR="/usr/lib/project"
_src() { local p; p=$(verify-lib "$1" "$LIBDIR/") && source "$p" || exit 1; }
_src "${LIBDIR}/common.sh"
readonly _PROJECT_NO_INIT=1
tmpdir=$(mktemp -d)
echo "$tmpdir"
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_warning "$output" "CLEANUP_TRAP" && ok "detects entry with temp but no cleanup trap" || fail "missed cleanup trap"

# Good: entry with cleanup trap
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly LIBDIR="/usr/lib/project"
readonly _PROJECT_NO_INIT=1
_src() { local p; p=$(verify-lib "$1" "$LIBDIR/") && source "$p" || exit 1; }
_src "${LIBDIR}/common.sh"
cleanup() {
    local exit_code=$?
    set +e
    rm -rf "$tmpdir"
    return $exit_code
}
trap cleanup EXIT
tmpdir=$(mktemp -d)
echo "$tmpdir"
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_no_warning "$output" "CLEANUP_TRAP" && ok "accepts entry with cleanup trap" || fail "flagged good cleanup trap"
has_no_warning "$output" "CLEANUP_ERREXIT" && ok "accepts cleanup with set +e" || fail "flagged cleanup with set +e"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# WARN: SHOPT_RESTORE
# ════════════════════════════════════════════════════════

section "WARN: SHOPT_RESTORE"

PROJ=$(mktemp -d)
ENTRY=$(make_entry "$PROJ")

# Bad: shopt without restore
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly LIBDIR="/usr/lib/project"
readonly _PROJECT_NO_INIT=1
_src() { local p; p=$(verify-lib "$1" "$LIBDIR/") && source "$p" || exit 1; }
_src "${LIBDIR}/common.sh"
shopt -s extglob
echo "work"
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_warning "$output" "SHOPT_RESTORE" && ok "detects shopt without restore" || fail "missed shopt restore"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# WARN: GLOB_NULLGLOB
# ════════════════════════════════════════════════════════

section "WARN: GLOB_NULLGLOB"

PROJ=$(mktemp -d)
ENTRY=$(make_entry "$PROJ")

# Bad: glob loop without nullglob
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly LIBDIR="/usr/lib/project"
readonly _PROJECT_NO_INIT=1
_src() { local p; p=$(verify-lib "$1" "$LIBDIR/") && source "$p" || exit 1; }
_src "${LIBDIR}/common.sh"
for f in *.sh; do
    echo "$f"
done
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_warning "$output" "GLOB_NULLGLOB" && ok "detects glob loop without nullglob" || fail "missed nullglob"

# Good: glob loop with nullglob
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly LIBDIR="/usr/lib/project"
readonly _PROJECT_NO_INIT=1
_src() { local p; p=$(verify-lib "$1" "$LIBDIR/") && source "$p" || exit 1; }
_src "${LIBDIR}/common.sh"
shopt -s nullglob
for f in *.sh; do
    echo "$f"
done
shopt -u nullglob
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_no_warning "$output" "GLOB_NULLGLOB" && ok "accepts glob loop with nullglob" || fail "flagged good nullglob"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# WARN: CLI_HELP
# ════════════════════════════════════════════════════════

section "WARN: CLI_HELP"

PROJ=$(mktemp -d)
ENTRY=$(make_entry "$PROJ")

# Bad: entry without --help
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly LIBDIR="/usr/lib/project"
readonly _PROJECT_NO_INIT=1
_src() { local p; p=$(verify-lib "$1" "$LIBDIR/") && source "$p" || exit 1; }
_src "${LIBDIR}/common.sh"
echo "main"
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_warning "$output" "CLI_HELP" && ok "detects entry without --help" || fail "missed CLI help"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# WARN: INPUT_VALIDATION
# ════════════════════════════════════════════════════════

section "WARN: INPUT_VALIDATION"

PROJ=$(mktemp -d)
LIB=$(make_lib "$PROJ")

# Bad: library handling DESTDIR without _validate_path
cat > "$PROJ/lib/$LIB" << 'EOF'
#!/usr/bin/env bash
install_files() {
    cp "$file" "$DESTDIR/usr/bin/"
}
EOF

output=$(lint_file "$PROJ/lib/$LIB")
has_warning "$output" "INPUT_VALIDATION" && ok "detects library with DESTDIR but no _validate_path" || fail "missed input validation"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# WARN: NAMEREF
# ════════════════════════════════════════════════════════

section "WARN: NAMEREF"

PROJ=$(mktemp -d)
LIB=$(make_lib "$PROJ")

# Bad: library with local -a but no -n
cat > "$PROJ/lib/$LIB" << 'EOF'
#!/usr/bin/env bash
bwrap_base() {
    local -a arr=()
    arr+=(--ro-bind /usr /usr)
    printf '%s\n' "${arr[@]}"
}
EOF

output=$(lint_file "$PROJ/lib/$LIB")
has_warning "$output" "NAMEREF" && ok "detects library building arrays without nameref" || fail "missed nameref"

# Good: library with nameref
cat > "$PROJ/lib/$LIB" << 'EOF'
#!/usr/bin/env bash
bwrap_base() {
    local -n _arr=$1
    _arr+=(--ro-bind /usr /usr)
}
EOF

output=$(lint_file "$PROJ/lib/$LIB")
has_no_warning "$output" "NAMEREF" && ok "accepts library with nameref" || fail "flagged good nameref"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# WARN: FUNCTION_NAMING
# ════════════════════════════════════════════════════════

section "WARN: FUNCTION_NAMING"

PROJ=$(mktemp -d)
LIB=$(make_lib "$PROJ")

# Bad: CamelCase function
cat > "$PROJ/lib/$LIB" << 'EOF'
#!/usr/bin/env bash
loadConfig() {
    echo "config"
}
EOF

output=$(lint_file "$PROJ/lib/$LIB")
has_warning "$output" "FUNCTION_NAMING" && ok "detects CamelCase function" || fail "missed function naming"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# WARN: SOURCE_UNSAFE
# ════════════════════════════════════════════════════════

section "WARN: SOURCE_UNSAFE"

PROJ=$(mktemp -d)
ENTRY=$(make_entry "$PROJ")

# Bad: entry sourcing common.sh without verify-lib wrapper
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly _PROJECT_NO_INIT=1
source "/usr/lib/project/common.sh"
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_warning "$output" "SOURCE_UNSAFE" && ok "detects sourcing without verify-lib" || fail "missed source unsafe"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# WARN: TMP_USAGE
# ════════════════════════════════════════════════════════

section "WARN: TMP_USAGE"

PROJ=$(mktemp -d)
ENTRY=$(make_entry "$PROJ")

# Bad: TMPDIR=/tmp directly
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly LIBDIR="/usr/lib/project"
readonly _PROJECT_NO_INIT=1
_src() { local p; p=$(verify-lib "$1" "$LIBDIR/") && source "$p" || exit 1; }
_src "${LIBDIR}/common.sh"
readonly TMPDIR=/tmp/project
mkdir -p "$TMPDIR"
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_warning "$output" "TMP_USAGE" && ok "detects /tmp usage" || fail "missed TMP usage"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# INFO: SHEBANG
# ════════════════════════════════════════════════════════

section "INFO: SHEBANG"

PROJ=$(mktemp -d)
LIB=$(make_lib "$PROJ")
mkdir -p "$PROJ/bin"

# Bad shebang for library
cat > "$PROJ/lib/$LIB" << 'EOF'
#!/bin/bash
lib_func() { echo "lib"; }
EOF

output=$(lint_file "$PROJ/lib/$LIB")
has_info "$output" "SHEBANG" && ok "detects library with wrong shebang" || fail "missed library shebang"

# Bad shebang for entry
ENTRY=$(make_entry "$PROJ")
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
readonly LIBDIR="/usr/lib/project"
readonly _PROJECT_NO_INIT=1
_src() { local p; p=$(verify-lib "$1" "$LIBDIR/") && source "$p" || exit 1; }
_src "${LIBDIR}/common.sh"
echo "entry"
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_info "$output" "SHEBANG" && ok "detects entry with env shebang" || fail "missed entry shebang"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# INFO: READONLY
# ════════════════════════════════════════════════════════

section "INFO: READONLY"

PROJ=$(mktemp -d)
ENTRY=$(make_entry "$PROJ")

# Bad: VERSION without readonly
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly LIBDIR="/usr/lib/project"
readonly _PROJECT_NO_INIT=1
_src() { local p; p=$(verify-lib "$1" "$LIBDIR/") && source "$p" || exit 1; }
_src "${LIBDIR}/common.sh"
VERSION=1.0.0
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
has_info "$output" "READONLY" && ok "detects VERSION without readonly" || fail "missed readonly"

# Good: readonly VERSION
cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly LIBDIR="/usr/lib/project"
readonly _PROJECT_NO_INIT=1
_src() { local p; p=$(verify-lib "$1" "$LIBDIR/") && source "$p" || exit 1; }
_src "${LIBDIR}/common.sh"
readonly VERSION=1.0.0
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$(lint_file "$PROJ/bin/$ENTRY")
# INFO level — check it doesn't flag readonly VERSION
! echo "$output" | grep -qF ":READONLY:" && ok "accepts readonly VERSION" || fail "flagged readonly VERSION"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# WARN: TEST_HAS_ERREXIT
# ════════════════════════════════════════════════════════

section "WARN: TEST_HAS_ERREXIT"

PROJ=$(mktemp -d)
TEST_F=$(make_test "$PROJ")

# Bad: test file with -e in header
cat > "$PROJ/tests/$TEST_F" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
# test file content
ok() { echo "pass"; }
ok "test"
EOF
chmod +x "$PROJ/tests/$TEST_F"

output=$(lint_file "$PROJ/tests/$TEST_F")
has_warning "$output" "TEST_HAS_ERREXIT" && ok "detects test file with -e" || fail "missed test errexit"

# Good: test file without -e
cat > "$PROJ/tests/$TEST_F" << 'EOF'
#!/usr/bin/env bash
set -uo pipefail
ok() { echo "pass"; }
ok "test"
EOF
chmod +x "$PROJ/tests/$TEST_F"

output=$(lint_file "$PROJ/tests/$TEST_F")
has_no_warning "$output" "TEST_HAS_ERREXIT" && ok "accepts test file without -e" || fail "flagged test without -e"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# --strict mode
# ════════════════════════════════════════════════════════

section "ERROR: --strict mode"

PROJ=$(mktemp -d)
TEST_F=$(make_test "$PROJ")

# Test with -e (generates TEST_HAS_ERREXIT warning)
cat > "$PROJ/tests/$TEST_F" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
ok() { echo "pass"; }
ok "test"
EOF
chmod +x "$PROJ/tests/$TEST_F"

# Without --strict: should pass (warnings allowed)
output=$("$LINT" "$PROJ/tests/$TEST_F" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && ok "non-strict exits 0 with only warnings" || fail "non-strict should exit 0"

# With --strict: should fail (warnings become errors)
"$LINT" --strict "$PROJ/tests/$TEST_F" >/dev/null 2>&1
rc=$?
[[ $rc -eq 1 ]] && ok "strict mode exits 1 with warnings" || fail "strict mode should exit 1"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# --json output
# ════════════════════════════════════════════════════════

section "ERROR: --json output"

PROJ=$(mktemp -d)
ENTRY=$(make_entry "$PROJ")

cat > "$PROJ/bin/$ENTRY" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly LIBDIR="/usr/lib/project"
readonly _PROJECT_NO_INIT=1
_src() { local p; p=$(verify-lib "$1" "$LIBDIR/") && source "$p" || exit 1; }
_src "${LIBDIR}/common.sh"
echo "ERROR: fail"
exit 1
EOF
chmod +x "$PROJ/bin/$ENTRY"

output=$("$LINT" --json "$PROJ/bin/$ENTRY" 2>&1)
echo "$output" | grep -q '^{' && ok "JSON output starts with {" || fail "JSON output broken"
echo "$output" | grep -q '"errors"' && ok "JSON has errors key" || fail "JSON missing errors key"
echo "$output" | grep -q '"warnings"' && ok "JSON has warnings key" || fail "JSON missing warnings key"

rm -rf "$PROJ"

# ════════════════════════════════════════════════════════
# --help and -V
# ════════════════════════════════════════════════════════

section "CLI: --help and -V"

"$LINT" --help >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 ]] && ok "--help exits 0" || fail "--help should exit 0"

"$LINT" -V >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 ]] && ok "-V exits 0" || fail "-V should exit 0"

"$LINT" -V 2>&1 | grep -qF "v0.1.0" && ok "-V shows version" || fail "-V missing version"

# ════════════════════════════════════════════════════════
# -p project mode
# ════════════════════════════════════════════════════════

section "ERROR: -p project mode"

PROJ_DIR=$(mktemp -d)
mkdir -p "$PROJ_DIR/bin" "$PROJ_DIR/lib" "$PROJ_DIR/tests"

cat > "$PROJ_DIR/bin/app" << 'EOF'
#!/bin/bash
set -euo pipefail
readonly LIBDIR="/usr/lib/project"
readonly _PROJECT_NO_INIT=1
_src() { local p; p=$(verify-lib "$1" "$LIBDIR/") && source "$p" || exit 1; }
_src "${LIBDIR}/common.sh"
case "${1:-}" in
    --help) echo "help"; exit 0 ;;
    -V|--version) echo "app 1.0"; exit 0 ;;
esac
EOF
chmod +x "$PROJ_DIR/bin/app"

cat > "$PROJ_DIR/lib/common.sh" << 'EOF'
#!/usr/bin/env bash
lib_func() { echo "lib"; }
EOF

cat > "$PROJ_DIR/tests/test.sh" << 'EOF'
#!/usr/bin/env bash
set -uo pipefail
ok() { echo "pass"; }
ok "test"
EOF

output=$(lint_project "$PROJ_DIR")
has_no_error "$output" "ENTRY_STRICTNESS" && ok "project mode: no entry strictness errors" || fail "project mode flagged good entry"
has_no_error "$output" "VERIFY_LIB" && ok "project mode: no verify-lib errors" || fail "project mode flagged good verify-lib"

rm -rf "$PROJ_DIR"

# ════════════════════════════════════════════════════════
# Summary
# ════════════════════════════════════════════════════════

summary

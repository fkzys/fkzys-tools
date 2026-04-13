#!/usr/bin/env bash
# tests/test_fkzys_audit.sh — Tests for fkzys-audit
# Run: bash tests/test_fkzys_audit.sh

source "$(dirname "${BASH_SOURCE[0]}")/test_harness.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT="${SCRIPT_DIR}/../bin/fkzys-audit"

audit_project() {
    local dir="$1"
    shift
    "$AUDIT" "$@" "$dir" 2>&1
}

has_error() {
    local output="$1" code="$2"
    echo "$output" | grep -qE "(ERROR|✗).*${code}"
}

has_warning() {
    local output="$1" code="$2"
    echo "$output" | grep -qE "(WARNING|⚠).*${code}"
}

has_info() {
    local output="$1" code="$2"
    echo "$output" | grep -qE "(INFO|ℹ).*${code}"
}

has_no_error() {
    local output="$1" code="$2"
    ! echo "$output" | grep -qE "(ERROR|✗).*${code}"
}

has_no_warning() {
    local output="$1" code="$2"
    ! echo "$output" | grep -qE "(WARNING|⚠).*${code}"
}

# ════════════════════════════════════════════════════════
# Common: LICENSE
# ════════════════════════════════════════════════════════

section "Common: LICENSE"

# Bad: no LICENSE
NO_LICENSE=$(mktemp -d)
cat > "$NO_LICENSE/Makefile" << 'EOF'
PREFIX = /usr
install:
	echo "install"
test:
	echo "test"
EOF

output=$(audit_project "$NO_LICENSE")
has_warning "$output" "LICENSE" && ok "detects missing LICENSE" || fail "missed missing LICENSE"
rm -rf "$NO_LICENSE"

# Good: has LICENSE
HAS_LICENSE=$(mktemp -d)
touch "$HAS_LICENSE/LICENSE"
cat > "$HAS_LICENSE/Makefile" << 'EOF'
PREFIX = /usr
install:
	install -Dm644 LICENSE $(PREFIX)/share/licenses/pkg/LICENSE
test:
	echo "test"
EOF

output=$(audit_project "$HAS_LICENSE")
has_no_warning "$output" "LICENSE" && ok "accepts project with LICENSE" || fail "flagged project with LICENSE"
rm -rf "$HAS_LICENSE"

# ════════════════════════════════════════════════════════
# Common: depends
# ════════════════════════════════════════════════════════

section "Common: depends"

# Bad: invalid depends format
BAD_DEPENDS=$(mktemp -d)
touch "$BAD_DEPENDS/LICENSE"
cat > "$BAD_DEPENDS/depends" << 'EOF'
# comment
python3
system
invalid-format
EOF

output=$(audit_project "$BAD_DEPENDS")
has_warning "$output" "invalid format" && ok "detects invalid depends format" || fail "missed depends format"
rm -rf "$BAD_DEPENDS"

# Good: valid depends format
GOOD_DEPENDS=$(mktemp -d)
touch "$GOOD_DEPENDS/LICENSE"
cat > "$GOOD_DEPENDS/depends" << 'EOF'
system:bash
gitpkg:verify-lib
EOF

output=$(audit_project "$GOOD_DEPENDS")
has_no_warning "$output" "invalid format" && ok "accepts valid depends format" || fail "flagged valid depends"
rm -rf "$GOOD_DEPENDS"

# ════════════════════════════════════════════════════════
# Common: Makefile
# ════════════════════════════════════════════════════════

section "Common: Makefile"

# Bad: no install target
BAD_MF=$(mktemp -d)
touch "$BAD_MF/LICENSE"
cat > "$BAD_MF/Makefile" << 'EOF'
PREFIX = /usr
clean:
	rm -rf build/
EOF

output=$(audit_project "$BAD_MF")
has_warning "$output" "MAKEFILE_INSTALL" && ok "detects Makefile without install target" || fail "missed install target"
rm -rf "$BAD_MF"

# Bad: PREFIX=/usr/local
BAD_PREFIX=$(mktemp -d)
touch "$BAD_PREFIX/LICENSE"
cat > "$BAD_PREFIX/Makefile" << 'EOF'
PREFIX = /usr/local
install:
	echo "install"
EOF

output=$(audit_project "$BAD_PREFIX")
has_warning "$output" "MAKEFILE_PREFIX" && ok "detects PREFIX=/usr/local" || fail "missed PREFIX check"
rm -rf "$BAD_PREFIX"

# ════════════════════════════════════════════════════════
# Common: CI
# ════════════════════════════════════════════════════════

section "Common: CI"

# Bad: CI without paths filter
BAD_CI=$(mktemp -d)
touch "$BAD_CI/LICENSE"
mkdir -p "$BAD_CI/.github/workflows"
cat > "$BAD_CI/.github/workflows/ci.yml" << 'EOF'
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "test"
EOF

output=$(audit_project "$BAD_CI")
has_warning "$output" "CI_PATHS" && ok "detects CI without paths filter" || fail "missed CI paths"
rm -rf "$BAD_CI"

# Bad: CI using make test
MAKE_CI=$(mktemp -d)
touch "$MAKE_CI/LICENSE"
mkdir -p "$MAKE_CI/.github/workflows"
cat > "$MAKE_CI/.github/workflows/ci.yml" << 'EOF'
on:
  push:
    paths:
      - 'bin/**'
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: make test
EOF

output=$(audit_project "$MAKE_CI")
has_warning "$output" "CI_MAKE_TEST" && ok "detects CI using make test" || fail "missed CI make test"
rm -rf "$MAKE_CI"

# ════════════════════════════════════════════════════════
# Common: test docs
# ════════════════════════════════════════════════════════

section "Common: test docs"

# Bad: tests/ dir without tests/README.md
BAD_TESTDOCS=$(mktemp -d)
touch "$BAD_TESTDOCS/LICENSE"
mkdir -p "$BAD_TESTDOCS/tests"

output=$(audit_project "$BAD_TESTDOCS" --all)
has_info "$output" "tests/README.md" && ok "detects missing tests/README.md" || fail "missed test docs"
rm -rf "$BAD_TESTDOCS"

# ════════════════════════════════════════════════════════
# Bash: entry shebang, strictness
# ════════════════════════════════════════════════════════

section "Bash: entry shebang, strictness"

# Bad: entry with env shebang
BAD_ENTRY_SHEBANG=$(mktemp -d)
touch "$BAD_ENTRY_SHEBANG/LICENSE"
mkdir -p "$BAD_ENTRY_SHEBANG/bin"
cat > "$BAD_ENTRY_SHEBANG/bin/app" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "app"
EOF
chmod +x "$BAD_ENTRY_SHEBANG/bin/app"

output=$(audit_project "$BAD_ENTRY_SHEBANG")
has_warning "$output" "ENTRY_SHEBANG" && ok "detects entry with env shebang" || fail "missed entry shebang"
rm -rf "$BAD_ENTRY_SHEBANG"

# Bad: entry without set -euo pipefail
BAD_ENTRY_STRICT=$(mktemp -d)
touch "$BAD_ENTRY_STRICT/LICENSE"
mkdir -p "$BAD_ENTRY_STRICT/bin"
cat > "$BAD_ENTRY_STRICT/bin/app" << 'EOF'
#!/bin/bash
echo "app"
EOF
chmod +x "$BAD_ENTRY_STRICT/bin/app"

output=$(audit_project "$BAD_ENTRY_STRICT")
has_warning "$output" "ENTRY_STRICTNESS" && ok "detects entry without set -euo pipefail" || fail "missed entry strictness"
rm -rf "$BAD_ENTRY_STRICT"

# ════════════════════════════════════════════════════════
# Bash: library shebang
# ════════════════════════════════════════════════════════

section "Bash: library shebang"

# Bad: library with #!/bin/bash
BAD_LIB_SHEBANG=$(mktemp -d)
touch "$BAD_LIB_SHEBANG/LICENSE"
mkdir -p "$BAD_LIB_SHEBANG/bin" "$BAD_LIB_SHEBANG/lib"
cat > "$BAD_LIB_SHEBANG/bin/app" << 'EOF'
#!/bin/bash
set -euo pipefail
echo "app"
EOF
chmod +x "$BAD_LIB_SHEBANG/bin/app"
cat > "$BAD_LIB_SHEBANG/lib/common.sh" << 'EOF'
#!/bin/bash
lib_func() { echo "lib"; }
EOF

output=$(audit_project "$BAD_LIB_SHEBANG")
has_warning "$output" "LIB_SHEBANG" && ok "detects library with #!/bin/bash" || fail "missed library shebang"
rm -rf "$BAD_LIB_SHEBANG"

# ════════════════════════════════════════════════════════
# Bash: man pages, completions, test_harness
# ════════════════════════════════════════════════════════

section "Bash: man, completions, test_harness"

# Info: no man/, completions/, test_harness.sh
BASH_INFO=$(mktemp -d)
touch "$BASH_INFO/LICENSE"
mkdir -p "$BASH_INFO/bin" "$BASH_INFO/tests"
cat > "$BASH_INFO/bin/app" << 'EOF'
#!/bin/bash
set -euo pipefail
echo "app"
EOF
chmod +x "$BASH_INFO/bin/app"

output=$(audit_project "$BASH_INFO" --all)
has_info "$output" "man/" && ok "suggests man pages" || fail "missed man pages suggestion"
has_info "$output" "completions/" && ok "suggests completions" || fail "missed completions suggestion"
has_info "$output" "test_harness.sh" && ok "suggests test_harness.sh" || fail "missed test_harness suggestion"
rm -rf "$BASH_INFO"

# ════════════════════════════════════════════════════════
# Go: cmd/, internal/, build flags
# ════════════════════════════════════════════════════════

section "Go: cmd/, internal/, build flags"

# Bad: no cmd/, no internal, no CGO_ENABLED
BAD_GO=$(mktemp -d)
touch "$BAD_GO/LICENSE"
cat > "$BAD_GO/go.mod" << 'EOF'
module example.com/app
go 1.24
EOF
cat > "$BAD_GO/Makefile" << 'EOF'
PREFIX = /usr
install:
	echo "install"
build:
	go build -trimpath -o app ./cmd/app
EOF

output=$(audit_project "$BAD_GO")
has_warning "$output" "cmd/" && ok "detects Go project without cmd/" || fail "missed cmd/"
has_warning "$output" "GO_BUILD_FLAGS" && ok "detects Go without CGO_ENABLED" || fail "missed Go build flags"
rm -rf "$BAD_GO"

# ════════════════════════════════════════════════════════
# C#: .csproj, test project
# ════════════════════════════════════════════════════════

section "C#: .csproj, test project"

# Bad: no test project
BAD_CS=$(mktemp -d)
touch "$BAD_CS/LICENSE"
cat > "$BAD_CS/App.csproj" << 'EOF'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup>
</Project>
EOF
cat > "$BAD_CS/Makefile" << 'EOF'
PREFIX = /usr
build:
	dotnet build
install:
	echo "install"
EOF

output=$(audit_project "$BAD_CS" --all)
has_info "$output" "*.Tests.csproj" && ok "suggests xUnit test project" || fail "missed C# test suggestion"
rm -rf "$BAD_CS"

# ════════════════════════════════════════════════════════
# Python: __main__.py
# ════════════════════════════════════════════════════════

section "Python: __main__.py"

# Bad: no __main__.py
BAD_PY=$(mktemp -d)
touch "$BAD_PY/LICENSE"
cat > "$BAD_PY/pyproject.toml" << 'EOF'
[project]
name = "example"
EOF
mkdir -p "$BAD_PY/bin"
cat > "$BAD_PY/bin/app" << 'EOF'
#!/usr/bin/env python3
print("app")
EOF
chmod +x "$BAD_PY/bin/app"

output=$(audit_project "$BAD_PY" --all)
has_info "$output" "__main__.py" && ok "suggests __main__.py" || fail "missed __main__.py suggestion"
rm -rf "$BAD_PY"

# ════════════════════════════════════════════════════════
# --all flag
# ════════════════════════════════════════════════════════

section "CLI: --all flag"

ALL_TEST=$(mktemp -d)
touch "$ALL_TEST/LICENSE"
mkdir -p "$ALL_TEST/tests"

# Without --all: no info output
output=$(audit_project "$ALL_TEST")
! echo "$output" | grep -q "INFO:" && ok "no INFO without --all" || fail "INFO shown without --all"

# With --all: info output
output=$(audit_project "$ALL_TEST" --all)
echo "$output" | grep -q "INFO:" && ok "INFO shown with --all" || fail "INFO not shown with --all"
rm -rf "$ALL_TEST"

# ════════════════════════════════════════════════════════
# --json output
# ════════════════════════════════════════════════════════

section "CLI: --json output"

JSON_TEST=$(mktemp -d)
touch "$JSON_TEST/LICENSE"

output=$(audit_project "$JSON_TEST" --json)
echo "$output" | grep -q '^{' && ok "JSON output starts with {" || fail "JSON broken"
echo "$output" | grep -q '"errors"' && ok "JSON has errors key" || fail "JSON missing errors"
echo "$output" | grep -q '"warnings"' && ok "JSON has warnings key" || fail "JSON missing warnings"
rm -rf "$JSON_TEST"

# ════════════════════════════════════════════════════════
# --lang filter
# ════════════════════════════════════════════════════════

section "CLI: --lang filter"

LANG_TEST=$(mktemp -d)
touch "$LANG_TEST/LICENSE"
cat > "$LANG_TEST/go.mod" << 'EOF'
module example.com/app
go 1.24
EOF

# Without filter: go warnings
output=$(audit_project "$LANG_TEST")
has_warning "$output" "cmd/" && ok "detects Go without cmd/ (auto-detect)" || fail "missed auto-detect Go"

# With --lang bash: no go warnings
output=$(audit_project "$LANG_TEST" --lang bash)
has_no_warning "$output" "cmd/" && ok "--lang bash suppresses Go warnings" || fail "lang filter broken"
rm -rf "$LANG_TEST"

# ════════════════════════════════════════════════════════
# --help and -V
# ════════════════════════════════════════════════════════

section "CLI: --help and -V"

"$AUDIT" --help >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 ]] && ok "--help exits 0" || fail "--help should exit 0"

"$AUDIT" -V >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 ]] && ok "-V exits 0" || fail "-V should exit 0"

"$AUDIT" -V 2>&1 | grep -qF "v0.1.0" && ok "-V shows version" || fail "-V missing version"

# ════════════════════════════════════════════════════════
# Summary
# ════════════════════════════════════════════════════════

summary
